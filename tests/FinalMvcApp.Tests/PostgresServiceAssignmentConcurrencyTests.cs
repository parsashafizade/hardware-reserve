using FinalMvcApp.Data;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;

namespace FinalMvcApp.Tests;

public class PostgresServiceAssignmentConcurrencyTests
{
    [PostgresFact]
    public async Task TwoAdminsSubmittingSameAssignment_ProduceOneVersionAndOneNotification()
    {
        var adminConnectionString = Environment.GetEnvironmentVariable(
            PostgresFactAttribute.ConnectionStringVariable)!;
        var databaseName = $"hr_assignment_test_{Guid.NewGuid():N}";
        var testConnectionString = new NpgsqlConnectionStringBuilder(adminConnectionString)
        {
            Database = databaseName,
            Pooling = false
        }.ConnectionString;

        await CreateDatabaseAsync(adminConnectionString, databaseName);
        try
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseNpgsql(testConnectionString)
                .Options;
            int adminOneId;
            int adminTwoId;
            int ownerId;
            int serverId;
            int reservationId;
            await using (var setup = new ApplicationDbContext(options))
            {
                await setup.Database.MigrateAsync();
                var adminOne = NewUser("concurrent-admin-1@test.local", UserRole.Admin);
                var adminTwo = NewUser("concurrent-admin-2@test.local", UserRole.Admin);
                var owner = NewUser("concurrent-owner@test.local", UserRole.User);
                var server = NewServer();
                setup.Users.AddRange(adminOne, adminTwo, owner);
                setup.Servers.Add(server);
                await setup.SaveChangesAsync();
                var reservation = new Reservation
                {
                    UserId = owner.Id,
                    ServerId = server.Id,
                    StartTime = DateTime.UtcNow.AddHours(1),
                    EndTime = DateTime.UtcNow.AddHours(4),
                    TotalPrice = 250_000m,
                    Status = ReservationStatus.Paid
                };
                setup.Reservations.Add(reservation);
                await setup.SaveChangesAsync();
                adminOneId = adminOne.Id;
                adminTwoId = adminTwo.Id;
                ownerId = owner.Id;
                serverId = server.Id;
                reservationId = reservation.Id;
            }

            await using var contextOne = new ApplicationDbContext(options);
            await using var contextTwo = new ApplicationDbContext(options);
            var serviceOne = BuildService(contextOne);
            var serviceTwo = BuildService(contextTwo);
            var gate = new TaskCompletionSource(
                TaskCreationOptions.RunContinuationsAsynchronously);
            var request = new AssignCredentialsDto
            {
                ReservationId = reservationId,
                AssignedIp = "203.0.113.200",
                AssignedUsername = "concurrent-user",
                AssignedPassword = "concurrent-secret"
            };

            var first = Task.Run(async () =>
            {
                await gate.Task;
                return await serviceOne.AssignCredentialsAsync(adminOneId, request);
            });
            var second = Task.Run(async () =>
            {
                await gate.Task;
                return await serviceTwo.AssignCredentialsAsync(adminTwoId, request);
            });
            gate.SetResult();
            await Task.WhenAll(first, second);

            await using var verification = new ApplicationDbContext(options);
            var persisted = await verification.Reservations
                .AsNoTracking()
                .SingleAsync(item => item.Id == reservationId);
            Assert.Equal("203.0.113.200", persisted.AssignedIp);
            Assert.Equal("concurrent-user", persisted.AssignedUsername);
            Assert.Equal("concurrent-secret", persisted.AssignedPassword);
            Assert.Equal(1, persisted.ServiceDetailsVersion);
            Assert.Equal(1, persisted.ServiceDetailsNotifiedVersion);
            Assert.Single(
                verification.UserNotifications,
                item => item.Type == UserNotificationType.ServiceDetailsAssigned
                    && item.ReservationId == reservationId);
            Assert.Single(
                verification.AdminAuditEvents,
                item => item.Action == AdminAuditAction.CredentialsAssigned
                    && item.EntityId == reservationId.ToString());
            var adminRepository = new AdminControlRepository(verification);
            var assignedPage = await adminRepository.GetReservationsAsync(
                null,
                null,
                AdminAssignmentFilter.Assigned,
                DateTime.UtcNow,
                1,
                20);
            var needsAssignmentPage = await adminRepository.GetReservationsAsync(
                null,
                null,
                AdminAssignmentFilter.NeedsAssignment,
                DateTime.UtcNow,
                1,
                20);
            Assert.Equal(reservationId, Assert.Single(assignedPage.Items).Id);
            Assert.Empty(needsAssignmentPage.Items);

            var competingReservation = new Reservation
            {
                UserId = ownerId,
                ServerId = serverId,
                StartTime = DateTime.UtcNow.AddHours(5),
                EndTime = DateTime.UtcNow.AddHours(8),
                TotalPrice = 250_000m,
                Status = ReservationStatus.Paid
            };
            verification.Reservations.Add(competingReservation);
            await verification.SaveChangesAsync();

            await using var contextThree = new ApplicationDbContext(options);
            await using var contextFour = new ApplicationDbContext(options);
            var serviceThree = BuildService(contextThree);
            var serviceFour = BuildService(contextFour);
            var competingGate = new TaskCompletionSource(
                TaskCreationOptions.RunContinuationsAsynchronously);
            var requestA = new AssignCredentialsDto
            {
                ReservationId = competingReservation.Id,
                AssignedIp = "203.0.113.201",
                AssignedUsername = "admin-one-value",
                AssignedPassword = "admin-one-secret"
            };
            var requestB = new AssignCredentialsDto
            {
                ReservationId = competingReservation.Id,
                AssignedIp = "203.0.113.202",
                AssignedUsername = "admin-two-value",
                AssignedPassword = "admin-two-secret"
            };
            var competingFirst = Task.Run(async () =>
            {
                await competingGate.Task;
                return await serviceThree.AssignCredentialsAsync(adminOneId, requestA);
            });
            var competingSecond = Task.Run(async () =>
            {
                await competingGate.Task;
                return await serviceFour.AssignCredentialsAsync(adminTwoId, requestB);
            });
            competingGate.SetResult();
            await Task.WhenAll(competingFirst, competingSecond);

            await using var finalVerification = new ApplicationDbContext(options);
            var competingPersisted = await finalVerification.Reservations
                .AsNoTracking()
                .SingleAsync(item => item.Id == competingReservation.Id);
            var completeTupleA = competingPersisted.AssignedIp == requestA.AssignedIp
                && competingPersisted.AssignedUsername == requestA.AssignedUsername
                && competingPersisted.AssignedPassword == requestA.AssignedPassword;
            var completeTupleB = competingPersisted.AssignedIp == requestB.AssignedIp
                && competingPersisted.AssignedUsername == requestB.AssignedUsername
                && competingPersisted.AssignedPassword == requestB.AssignedPassword;
            Assert.True(completeTupleA || completeTupleB);
            Assert.Equal(2, competingPersisted.ServiceDetailsVersion);
            Assert.Equal(2, competingPersisted.ServiceDetailsNotifiedVersion);
            Assert.Equal(
                2,
                await finalVerification.UserNotifications.CountAsync(item =>
                    item.Type == UserNotificationType.ServiceDetailsAssigned
                    && item.ReservationId == competingReservation.Id));
            Assert.Equal(
                2,
                await finalVerification.AdminAuditEvents.CountAsync(item =>
                    item.Action == AdminAuditAction.CredentialsAssigned
                    && item.EntityId == competingReservation.Id.ToString()));
        }
        finally
        {
            NpgsqlConnection.ClearAllPools();
            await DropDatabaseAsync(adminConnectionString, databaseName);
        }
    }

    [PostgresFact]
    public async Task TwoAdminsSubmittingDifferentAssignments_PersistOneCompleteTuplePerVersion()
    {
        var adminConnectionString = Environment.GetEnvironmentVariable(
            PostgresFactAttribute.ConnectionStringVariable)!;
        var databaseName = $"hr_assignment_test_{Guid.NewGuid():N}";
        var testConnectionString = new NpgsqlConnectionStringBuilder(adminConnectionString)
        {
            Database = databaseName,
            Pooling = false
        }.ConnectionString;

        await CreateDatabaseAsync(adminConnectionString, databaseName);
        try
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseNpgsql(testConnectionString)
                .Options;
            int adminOneId;
            int adminTwoId;
            int reservationId;
            await using (var setup = new ApplicationDbContext(options))
            {
                await setup.Database.MigrateAsync();
                var adminOne = NewUser("different-admin-1@test.local", UserRole.Admin);
                var adminTwo = NewUser("different-admin-2@test.local", UserRole.Admin);
                var owner = NewUser("different-owner@test.local", UserRole.User);
                var server = NewServer();
                setup.Users.AddRange(adminOne, adminTwo, owner);
                setup.Servers.Add(server);
                await setup.SaveChangesAsync();
                var reservation = new Reservation
                {
                    UserId = owner.Id,
                    ServerId = server.Id,
                    StartTime = DateTime.UtcNow.AddHours(1),
                    EndTime = DateTime.UtcNow.AddHours(4),
                    TotalPrice = 250_000m,
                    Status = ReservationStatus.Paid
                };
                setup.Reservations.Add(reservation);
                await setup.SaveChangesAsync();
                adminOneId = adminOne.Id;
                adminTwoId = adminTwo.Id;
                reservationId = reservation.Id;
            }

            await using var contextOne = new ApplicationDbContext(options);
            await using var contextTwo = new ApplicationDbContext(options);
            var serviceOne = BuildService(contextOne);
            var serviceTwo = BuildService(contextTwo);
            var gate = new TaskCompletionSource(
                TaskCreationOptions.RunContinuationsAsynchronously);
            var firstRequest = new AssignCredentialsDto
            {
                ReservationId = reservationId,
                AssignedIp = "203.0.113.210",
                AssignedUsername = "first-admin",
                AssignedPassword = "first-complete-secret"
            };
            var secondRequest = new AssignCredentialsDto
            {
                ReservationId = reservationId,
                AssignedIp = "203.0.113.220",
                AssignedUsername = "second-admin",
                AssignedPassword = "second-complete-secret"
            };

            var first = Task.Run(async () =>
            {
                await gate.Task;
                return await serviceOne.AssignCredentialsAsync(adminOneId, firstRequest);
            });
            var second = Task.Run(async () =>
            {
                await gate.Task;
                return await serviceTwo.AssignCredentialsAsync(adminTwoId, secondRequest);
            });
            gate.SetResult();
            await Task.WhenAll(first, second);

            await using var verification = new ApplicationDbContext(options);
            var persisted = await verification.Reservations
                .AsNoTracking()
                .SingleAsync(item => item.Id == reservationId);
            var isFirstTuple = persisted.AssignedIp == firstRequest.AssignedIp
                && persisted.AssignedUsername == firstRequest.AssignedUsername
                && persisted.AssignedPassword == firstRequest.AssignedPassword;
            var isSecondTuple = persisted.AssignedIp == secondRequest.AssignedIp
                && persisted.AssignedUsername == secondRequest.AssignedUsername
                && persisted.AssignedPassword == secondRequest.AssignedPassword;
            Assert.True(isFirstTuple || isSecondTuple);
            Assert.Equal(2, persisted.ServiceDetailsVersion);
            Assert.Equal(2, persisted.ServiceDetailsNotifiedVersion);
            Assert.Equal(
                2,
                verification.UserNotifications.Count(item =>
                    item.Type == UserNotificationType.ServiceDetailsAssigned
                    && item.ReservationId == reservationId));
            Assert.Equal(
                2,
                verification.AdminAuditEvents.Count(item =>
                    item.Action == AdminAuditAction.CredentialsAssigned
                    && item.EntityId == reservationId.ToString()));
        }
        finally
        {
            NpgsqlConnection.ClearAllPools();
            await DropDatabaseAsync(adminConnectionString, databaseName);
        }
    }

    private static AdminService BuildService(ApplicationDbContext dbContext)
    {
        var timeProvider = TimeProvider.System;
        var reservationRepository = new ReservationRepository(dbContext);
        var notificationService = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            timeProvider,
            NullLogger<UserNotificationService>.Instance);
        var serviceDetailsNotificationService = new ServiceDetailsNotificationService(
            reservationRepository,
            notificationService,
            timeProvider,
            NullLogger<ServiceDetailsNotificationService>.Instance);
        return new AdminService(
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            reservationRepository,
            new PaymentRepository(dbContext),
            serviceDetailsNotificationService,
            new AdminControlRepository(dbContext),
            timeProvider);
    }

    private static User NewUser(string email, UserRole role) => new()
    {
        FullName = email,
        Email = email,
        PasswordHash = "hash",
        Role = role,
        IsEmailVerified = true,
        CreatedAt = DateTime.UtcNow
    };

    private static Server NewServer() => new()
    {
        CPU = "AMD EPYC",
        GPU = "NVIDIA H100",
        RAM = "128GB",
        Storage = "2TB NVMe",
        OS = "Ubuntu 24.04",
        PricePerHour = 100_000m,
        PricePerDay = 1_800_000m,
        IsActive = true
    };

    private static async Task CreateDatabaseAsync(
        string connectionString,
        string databaseName)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"CREATE DATABASE \"{databaseName}\"";
        await command.ExecuteNonQueryAsync();
    }

    private static async Task DropDatabaseAsync(
        string connectionString,
        string databaseName)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using (var terminate = connection.CreateCommand())
        {
            terminate.CommandText =
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                + "WHERE datname = @databaseName AND pid <> pg_backend_pid()";
            terminate.Parameters.AddWithValue("databaseName", databaseName);
            await terminate.ExecuteNonQueryAsync();
        }

        await using var drop = connection.CreateCommand();
        drop.CommandText = $"DROP DATABASE IF EXISTS \"{databaseName}\"";
        await drop.ExecuteNonQueryAsync();
    }
}

internal sealed class PostgresFactAttribute : FactAttribute
{
    public const string ConnectionStringVariable = "TEST_POSTGRES_CONNECTION_STRING";

    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(ConnectionStringVariable)))
        {
            Skip = $"Set {ConnectionStringVariable} to run the PostgreSQL concurrency test.";
        }
    }
}
