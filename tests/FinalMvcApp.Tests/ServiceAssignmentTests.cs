using FinalMvcApp.Controllers;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using System.Reflection;
using System.Security.Claims;

namespace FinalMvcApp.Tests;

public class ServiceAssignmentTests
{
    [Fact]
    public async Task FirstAssignment_PersistsReadableAdminDetail_AndNotifiesOwnerWithoutSecrets()
    {
        await using var dbContext = TestDbFactory.Create();
        var now = new DateTime(2026, 8, 23, 9, 0, 0, DateTimeKind.Utc);
        var (admin, owner, other, server) = await SeedAsync(dbContext);
        var reservation = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(2),
            now.AddHours(6));
        var realtime = new RecordingUserNotificationRealtimeNotifier();
        var (assignmentService, controlService) = BuildServices(
            dbContext,
            new FixedTimeProvider(now),
            realtime);

        var assigned = await assignmentService.AssignCredentialsAsync(admin.Id, new AssignCredentialsDto
        {
            ReservationId = reservation.Id,
            AssignedIp = " 203.0.113.45 ",
            AssignedUsername = " customer ",
            AssignedPassword = " assigned-secret "
        });

        Assert.True(assigned.CredentialsAssigned);
        Assert.Equal("Assigned", assigned.AssignmentStatus);
        Assert.Equal("203.0.113.45", assigned.AssignedIp);
        Assert.Equal("customer", assigned.AssignedUsername);
        Assert.Equal("assigned-secret", assigned.AssignedPassword);

        var reopened = await controlService.GetReservationAsync(reservation.Id);
        Assert.Equal(assigned.AssignedIp, reopened.AssignedIp);
        Assert.Equal(assigned.AssignedUsername, reopened.AssignedUsername);
        Assert.Equal(assigned.AssignedPassword, reopened.AssignedPassword);

        var notification = Assert.Single(dbContext.UserNotifications);
        Assert.Equal(owner.Id, notification.UserId);
        Assert.NotEqual(other.Id, notification.UserId);
        Assert.Equal(UserNotificationType.ServiceDetailsAssigned, notification.Type);
        Assert.Equal(reservation.Id, notification.ReservationId);
        Assert.DoesNotContain("203.0.113.45", notification.DeduplicationKey);
        Assert.DoesNotContain("customer", notification.DeduplicationKey);
        Assert.DoesNotContain("assigned-secret", notification.DeduplicationKey);
        Assert.DoesNotContain("assigned-secret", notification.Message ?? string.Empty);
        Assert.Single(realtime.Deliveries, item => item.UserId == owner.Id);

        var audit = Assert.Single(dbContext.AdminAuditEvents);
        Assert.DoesNotContain("203.0.113.45", audit.Details ?? string.Empty);
        Assert.DoesNotContain("customer", audit.Details ?? string.Empty);
        Assert.DoesNotContain("assigned-secret", audit.Details ?? string.Empty);
        var persisted = await dbContext.Reservations.FindAsync(reservation.Id);
        Assert.Equal(1, persisted!.ServiceDetailsVersion);
        Assert.Equal(1, persisted.ServiceDetailsNotifiedVersion);
    }

    [Fact]
    public async Task DuplicateAssignment_IsIdempotent_WhileMeaningfulUpdateNotifiesOnce()
    {
        await using var dbContext = TestDbFactory.Create();
        var now = new DateTime(2026, 8, 23, 9, 0, 0, DateTimeKind.Utc);
        var (admin, owner, _, server) = await SeedAsync(dbContext);
        var reservation = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(1),
            now.AddHours(4));
        var (service, _) = BuildServices(dbContext, new FixedTimeProvider(now));
        var request = new AssignCredentialsDto
        {
            ReservationId = reservation.Id,
            AssignedIp = "203.0.113.46",
            AssignedUsername = "customer",
            AssignedPassword = "first-secret"
        };

        await service.AssignCredentialsAsync(admin.Id, request);
        await service.AssignCredentialsAsync(admin.Id, request);

        Assert.Single(dbContext.UserNotifications);
        Assert.Single(dbContext.AdminAuditEvents);

        request.AssignedPassword = "replacement-secret";
        var updated = await service.AssignCredentialsAsync(admin.Id, request);
        await service.AssignCredentialsAsync(admin.Id, request);

        Assert.Equal("replacement-secret", updated.AssignedPassword);
        Assert.Equal(2, dbContext.UserNotifications.Count());
        Assert.Equal(2, dbContext.AdminAuditEvents.Count());
        Assert.All(dbContext.UserNotifications, item =>
        {
            Assert.Equal(owner.Id, item.UserId);
            Assert.Equal(UserNotificationType.ServiceDetailsAssigned, item.Type);
            Assert.DoesNotContain("first-secret", item.DeduplicationKey);
            Assert.DoesNotContain("replacement-secret", item.DeduplicationKey);
        });
    }

    [Fact]
    public async Task FailedIneligibleAssignment_DoesNotPersistCredentialsOrNotification()
    {
        await using var dbContext = TestDbFactory.Create();
        var now = new DateTime(2026, 8, 23, 9, 0, 0, DateTimeKind.Utc);
        var (admin, owner, _, server) = await SeedAsync(dbContext);
        var reservation = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.PendingPayment,
            now.AddHours(1),
            now.AddHours(4));
        var (service, _) = BuildServices(dbContext, new FixedTimeProvider(now));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.AssignCredentialsAsync(admin.Id, new AssignCredentialsDto
            {
                ReservationId = reservation.Id,
                AssignedIp = "203.0.113.47",
                AssignedUsername = "customer",
                AssignedPassword = "must-not-persist"
            }));

        var persisted = await dbContext.Reservations.FindAsync(reservation.Id);
        Assert.Null(persisted!.AssignedIp);
        Assert.Null(persisted.AssignedUsername);
        Assert.Null(persisted.AssignedPassword);
        Assert.Empty(dbContext.UserNotifications);
        Assert.Empty(dbContext.AdminAuditEvents);
    }

    [Fact]
    public async Task TransientNotificationFailure_RemainsPendingAndWorkerReconcilesDurably()
    {
        await using var dbContext = TestDbFactory.Create();
        var now = new DateTime(2026, 8, 23, 9, 0, 0, DateTimeKind.Utc);
        var (admin, owner, _, server) = await SeedAsync(dbContext);
        var reservation = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(1),
            now.AddHours(4));
        var reservationRepository = new ReservationRepository(dbContext);
        var unavailableNotifications = new UnavailableUserNotificationService();
        var failedDelivery = new ServiceDetailsNotificationService(
            reservationRepository,
            unavailableNotifications,
            new FixedTimeProvider(now),
            NullLogger<ServiceDetailsNotificationService>.Instance);
        var assignmentService = new AdminService(
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            reservationRepository,
            new PaymentRepository(dbContext),
            failedDelivery,
            new AdminControlRepository(dbContext),
            new FixedTimeProvider(now));

        await assignmentService.AssignCredentialsAsync(admin.Id, new AssignCredentialsDto
        {
            ReservationId = reservation.Id,
            AssignedIp = "203.0.113.48",
            AssignedUsername = "customer",
            AssignedPassword = "retry-secret"
        });

        Assert.Empty(dbContext.UserNotifications);
        Assert.Equal(1, reservation.ServiceDetailsVersion);
        Assert.Equal(0, reservation.ServiceDetailsNotifiedVersion);

        var durableNotifications = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            new FixedTimeProvider(now),
            NullLogger<UserNotificationService>.Instance);
        var reconciler = new ServiceDetailsNotificationService(
            reservationRepository,
            durableNotifications,
            new FixedTimeProvider(now),
            NullLogger<ServiceDetailsNotificationService>.Instance);
        await reconciler.ProcessPendingAsync();
        await reconciler.ProcessPendingAsync();

        var notification = Assert.Single(dbContext.UserNotifications);
        Assert.Equal(owner.Id, notification.UserId);
        Assert.Equal(reservation.Id, notification.ReservationId);
        Assert.Equal(UserNotificationType.ServiceDetailsAssigned, notification.Type);
        Assert.Equal(1, reservation.ServiceDetailsNotifiedVersion);
    }

    [Fact]
    public async Task AssignmentFilter_UsesPaidFuturePersistedCredentialState_AndCombinesWithStatus()
    {
        await using var dbContext = TestDbFactory.Create();
        var now = new DateTime(2026, 8, 23, 9, 0, 0, DateTimeKind.Utc);
        var (_, owner, _, server) = await SeedAsync(dbContext);
        var needsAssignment = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(2),
            now.AddHours(5));
        var assigned = await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(3),
            now.AddHours(6),
            assigned: true);
        await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.PendingPayment,
            now.AddHours(2),
            now.AddHours(5));
        await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Paid,
            now.AddHours(-5),
            now.AddHours(-1));
        await AddReservationAsync(
            dbContext,
            owner.Id,
            server.Id,
            ReservationStatus.Cancelled,
            now.AddHours(2),
            now.AddHours(5),
            assigned: true);
        var (_, service) = BuildServices(dbContext, new FixedTimeProvider(now));

        var needs = await service.GetReservationsAsync(new AdminReservationQueryDto
        {
            AssignmentStatus = "NeedsAssignment",
            PageSize = 100
        });
        var provisioned = await service.GetReservationsAsync(new AdminReservationQueryDto
        {
            AssignmentStatus = "Assigned",
            PageSize = 100
        });
        var upcomingAssigned = await service.GetReservationsAsync(new AdminReservationQueryDto
        {
            Status = "Upcoming",
            AssignmentStatus = "Assigned",
            PageSize = 100
        });

        Assert.Equal(needsAssignment.Id, Assert.Single(needs.Items).ReservationId);
        Assert.Equal("NotAssigned", needs.Items[0].AssignmentStatus);
        Assert.Equal(assigned.Id, Assert.Single(provisioned.Items).ReservationId);
        Assert.Equal("Assigned", provisioned.Items[0].AssignmentStatus);
        Assert.Equal(assigned.Id, Assert.Single(upcomingAssigned.Items).ReservationId);

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.GetReservationsAsync(new AdminReservationQueryDto
            {
                AssignmentStatus = "FrontendOnlyFlag"
            }));
    }

    [Fact]
    public void AssignmentSecrets_AreConfinedToAdminOnlyDetailContract()
    {
        var authorize = typeof(AdminManagementController)
            .GetCustomAttribute<AuthorizeAttribute>();

        Assert.NotNull(authorize);
        Assert.Equal("Admin", authorize!.Roles);
        Assert.Null(typeof(AdminOrderDto).GetProperty(nameof(AdminReservationDetailDto.AssignedIp)));
        Assert.Null(typeof(AdminOrderDto).GetProperty(nameof(AdminReservationDetailDto.AssignedUsername)));
        Assert.Null(typeof(AdminOrderDto).GetProperty(nameof(AdminReservationDetailDto.AssignedPassword)));
        Assert.NotNull(typeof(AdminReservationDetailDto).GetProperty(nameof(AdminReservationDetailDto.AssignedPassword)));

        var detailCachePolicy = typeof(AdminOperationsController)
            .GetMethod(nameof(AdminOperationsController.GetReservation))!
            .GetCustomAttribute<Microsoft.AspNetCore.Mvc.ResponseCacheAttribute>();
        var assignmentCachePolicy = typeof(AdminManagementController)
            .GetMethod(nameof(AdminManagementController.AssignCredentials))!
            .GetCustomAttribute<Microsoft.AspNetCore.Mvc.ResponseCacheAttribute>();
        Assert.True(detailCachePolicy?.NoStore);
        Assert.Equal(
            Microsoft.AspNetCore.Mvc.ResponseCacheLocation.None,
            detailCachePolicy?.Location);
        Assert.True(assignmentCachePolicy?.NoStore);
        Assert.Equal(
            Microsoft.AspNetCore.Mvc.ResponseCacheLocation.None,
            assignmentCachePolicy?.Location);
    }

    [Fact]
    public async Task AssignmentEndpointPolicy_RejectsNormalUser_AndAllowsAdmin()
    {
        var services = new ServiceCollection()
            .AddLogging()
            .AddAuthorization()
            .BuildServiceProvider();
        var policyProvider = services.GetRequiredService<IAuthorizationPolicyProvider>();
        var authorizationService = services.GetRequiredService<IAuthorizationService>();
        var authorizeData = typeof(AdminManagementController)
            .GetCustomAttributes(inherit: true)
            .OfType<IAuthorizeData>();
        var policy = await AuthorizationPolicy.CombineAsync(policyProvider, authorizeData);
        Assert.NotNull(policy);

        static ClaimsPrincipal Principal(string role) => new(new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, "42"),
                new Claim(ClaimTypes.Role, role)
            ],
            authenticationType: "Phase1Test"));

        Assert.False((await authorizationService.AuthorizeAsync(
            Principal("User"),
            resource: null,
            policy!)).Succeeded);
        Assert.True((await authorizationService.AuthorizeAsync(
            Principal("Admin"),
            resource: null,
            policy)).Succeeded);
    }

    private static (AdminService Assignment, AdminControlService Control) BuildServices(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        TimeProvider timeProvider,
        RecordingUserNotificationRealtimeNotifier? realtime = null)
    {
        realtime ??= new RecordingUserNotificationRealtimeNotifier();
        IUserNotificationService notificationService = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            realtime,
            timeProvider,
            NullLogger<UserNotificationService>.Instance);
        var reservationRepository = new ReservationRepository(dbContext);
        var adminRepository = new AdminControlRepository(dbContext);
        var serviceDetailsNotificationService = new ServiceDetailsNotificationService(
            reservationRepository,
            notificationService,
            timeProvider,
            NullLogger<ServiceDetailsNotificationService>.Instance);
        return (
            new AdminService(
                new UserRepository(dbContext),
                new ServerRepository(dbContext),
                reservationRepository,
                new PaymentRepository(dbContext),
                serviceDetailsNotificationService,
                adminRepository,
                timeProvider),
            new AdminControlService(
                adminRepository,
                new ServerRepository(dbContext),
                reservationRepository,
                notificationService,
                new BCryptPasswordHasher(),
                timeProvider));
    }

    private static async Task<(User Admin, User Owner, User Other, Server Server)> SeedAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var admin = NewUser("assignment-admin@test.local", UserRole.Admin);
        var owner = NewUser("assignment-owner@test.local", UserRole.User);
        var other = NewUser("assignment-other@test.local", UserRole.User);
        var server = new Server
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
        await dbContext.Users.AddRangeAsync(admin, owner, other);
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();
        return (admin, owner, other, server);
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

    private static async Task<Reservation> AddReservationAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        int userId,
        int serverId,
        ReservationStatus status,
        DateTime startTime,
        DateTime endTime,
        bool assigned = false)
    {
        var reservation = new Reservation
        {
            UserId = userId,
            ServerId = serverId,
            Status = status,
            StartTime = startTime,
            EndTime = endTime,
            TotalPrice = 100_000m,
            AssignedIp = assigned ? "203.0.113.100" : null,
            AssignedUsername = assigned ? "assigned-user" : null,
            AssignedPassword = assigned ? "assigned-password" : null
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();
        return reservation;
    }

    private sealed class UnavailableUserNotificationService : IUserNotificationService
    {
        public Task<FinalMvcApp.DTOs.Common.CursorPageDto<FinalMvcApp.DTOs.Notifications.UserNotificationDto>> GetForUserAsync(
            int userId,
            FinalMvcApp.DTOs.Notifications.NotificationQueryDto query,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<FinalMvcApp.DTOs.Notifications.NotificationUnreadCountDto> GetUnreadCountAsync(
            int userId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<FinalMvcApp.DTOs.Notifications.UserNotificationDto> MarkReadAsync(
            int userId,
            Guid notificationId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<FinalMvcApp.DTOs.Notifications.NotificationUnreadCountDto> MarkAllReadAsync(
            int userId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();

        public Task<FinalMvcApp.DTOs.Notifications.UserNotificationDto?> DispatchAsync(
            UserNotificationRequest request,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<FinalMvcApp.DTOs.Notifications.UserNotificationDto?>(null);

        public Task<IReadOnlyList<FinalMvcApp.DTOs.Notifications.UserNotificationDto>> DispatchManyAsync(
            IEnumerable<UserNotificationRequest> requests,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<FinalMvcApp.DTOs.Notifications.UserNotificationDto>>([]);

        public Task<bool> ExistsAsync(
            int userId,
            string deduplicationKey,
            CancellationToken cancellationToken = default) => Task.FromResult(false);
    }
}
