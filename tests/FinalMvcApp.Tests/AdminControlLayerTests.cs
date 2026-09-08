using FinalMvcApp.Controllers;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Logging.Abstractions;
using System.Reflection;

namespace FinalMvcApp.Tests;

public class AdminControlLayerTests
{
    [Fact]
    public async Task ManagedCapabilities_ArePersistedAndAudited()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, _, server) = await SeedAsync(dbContext);
        var adminRepository = new AdminControlRepository(dbContext);
        var service = new ServerService(
            new ServerRepository(dbContext),
            SupportTestFactory.CreateMapper(),
            adminRepository,
            TimeProvider.System);

        var updated = await service.UpdateAsync(admin.Id, server.Id, new UpdateServerDto
        {
            CPU = server.CPU,
            GPU = server.GPU,
            RAM = server.RAM,
            Storage = server.Storage,
            OS = server.OS,
            PricePerHour = server.PricePerHour,
            PricePerDay = server.PricePerDay,
            IsActive = true,
            OperationalStatus = ServerOperationalStatus.Available.ToString(),
            FinderEligible = true,
            CpuCapabilityLevel = 91,
            GpuCapabilityLevel = 96,
            PerformanceTier = ServerPerformanceTier.Extreme.ToString(),
            WorkloadCapabilities =
            [
                new ServerWorkloadCapabilityDto
                {
                    WorkloadType = ServerWorkloadType.ModelTraining.ToString(),
                    SuitabilityLevel = 5
                },
                new ServerWorkloadCapabilityDto
                {
                    WorkloadType = ServerWorkloadType.Inference.ToString(),
                    SuitabilityLevel = 4
                }
            ]
        });

        Assert.Equal(91, updated.CpuCapabilityLevel);
        Assert.Equal(96, updated.GpuCapabilityLevel);
        Assert.Equal("Extreme", updated.PerformanceTier);
        Assert.Equal(2, updated.WorkloadCapabilities.Count);
        Assert.Contains(updated.WorkloadCapabilities, item =>
            item.WorkloadType == "ModelTraining" && item.SuitabilityLevel == 5);
        Assert.Single(dbContext.AdminAuditEvents, item =>
            item.Action == AdminAuditAction.ServerConfigurationChanged
            && item.EntityId == server.Id.ToString());
    }

    [Fact]
    public async Task MaintenanceWindow_BlocksQuoteAndReservationThroughSharedAvailabilityRules()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, user, server) = await SeedAsync(dbContext);
        var now = DateTime.UtcNow;
        var controlService = BuildControlService(dbContext, new FixedTimeProvider(now));

        await controlService.CreateMaintenanceWindowAsync(admin.Id, server.Id, new CreateMaintenanceWindowDto
        {
            StartTime = now.AddHours(2),
            EndTime = now.AddHours(5),
            Reason = "Scheduled firmware work"
        });

        var reservationService = BuildReservationService(dbContext);
        var request = new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = now.AddHours(3),
            EndTime = now.AddHours(4)
        };

        var quote = await reservationService.QuoteAsync(request);
        Assert.False(quote.IsAvailable);

        var exception = await Assert.ThrowsAsync<ApiException>(() =>
            reservationService.CreateAsync(user.Id, request));
        Assert.Equal(ApiErrorCodes.ReservationTimeConflict, exception.Code);
        Assert.Empty(dbContext.Reservations);

        var availableQuote = await reservationService.QuoteAsync(new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = now.AddHours(6),
            EndTime = now.AddHours(7)
        });
        Assert.True(availableQuote.IsAvailable);
    }

    [Fact]
    public async Task ManualNotification_UsesDurableUserNotificationPathAndCreatesAudit()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, user, _) = await SeedAsync(dbContext);
        var realtime = new RecordingUserNotificationRealtimeNotifier();
        var notificationService = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            realtime,
            TimeProvider.System,
            NullLogger<UserNotificationService>.Instance);
        var service = BuildControlService(dbContext, TimeProvider.System, notificationService);

        var result = await service.SendNotificationAsync(admin.Id, new AdminSendNotificationDto
        {
            RecipientScope = AdminNotificationRecipientScope.User.ToString(),
            UserId = user.Id,
            Title = "Planned service update",
            Message = "Review your upcoming reservation details.",
            Category = "Reservation"
        });

        Assert.Equal(1, result.TargetCount);
        var notification = Assert.Single(dbContext.UserNotifications);
        Assert.Equal(user.Id, notification.UserId);
        Assert.Equal(UserNotificationType.AdminMessage, notification.Type);
        Assert.Equal(UserNotificationSource.Admin, notification.Source);
        Assert.Equal("Planned service update", notification.Title);
        Assert.Equal("Review your upcoming reservation details.", notification.Message);
        Assert.Single(realtime.Deliveries);
        Assert.Single(dbContext.AdminAuditEvents, item => item.Action == AdminAuditAction.ManualNotificationSent);
        Assert.Null(typeof(FinalMvcApp.DTOs.Notifications.UserNotificationDto)
            .GetProperty("CreatedByAdminUserId", BindingFlags.Public | BindingFlags.Instance));

        await notificationService.DispatchAsync(new UserNotificationRequest(
            user.Id,
            UserNotificationType.ReservationCreated,
            $"test-system:{Guid.NewGuid():N}"));
        var systemNotification = dbContext.UserNotifications.Single(item =>
            item.Type == UserNotificationType.ReservationCreated);
        systemNotification.ReadAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var adminDeliveries = await service.GetNotificationDeliveriesAsync(
            new AdminNotificationHistoryQueryDto
            {
                Source = UserNotificationSource.Admin.ToString(),
                IsRead = false
            });
        var delivery = Assert.Single(adminDeliveries.Items);
        Assert.Equal(user.Email, delivery.UserEmail);
        Assert.Equal(admin.Id, delivery.CreatedByAdminUserId);
        Assert.Equal(UserNotificationSource.Admin.ToString(), delivery.Source);
        Assert.Equal(2, dbContext.UserNotifications.Count());
    }

    [Fact]
    public async Task MaintenanceWindow_CannotOverlapAnExistingReservation()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, user, server) = await SeedAsync(dbContext);
        var now = DateTime.UtcNow;
        await dbContext.Reservations.AddAsync(new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = now.AddHours(3),
            EndTime = now.AddHours(6),
            TotalPrice = 300_000m,
            Status = ReservationStatus.Paid
        });
        await dbContext.SaveChangesAsync();
        var service = BuildControlService(dbContext, new FixedTimeProvider(now));

        await Assert.ThrowsAsync<ApiException>(() =>
            service.CreateMaintenanceWindowAsync(admin.Id, server.Id, new CreateMaintenanceWindowDto
            {
                StartTime = now.AddHours(4),
                EndTime = now.AddHours(5)
            }));

        Assert.Empty(dbContext.ServerMaintenanceWindows);
    }

    [Fact]
    public async Task AdminCancellation_IsSingleUseAndPreservesPaymentState()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, user, server) = await SeedAsync(dbContext);
        var now = DateTime.UtcNow;
        var reservation = new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = now.AddHours(2),
            EndTime = now.AddHours(4),
            Status = ReservationStatus.Paid,
            TotalPrice = 150_000m,
            AssignedIp = "203.0.113.30",
            AssignedUsername = "customer",
            AssignedPassword = "never-return-this-value",
            Payment = new Payment
            {
                Amount = 150_000m,
                PaymentDate = now,
                Status = PaymentStatus.Completed
            }
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();
        var service = BuildControlService(dbContext, new FixedTimeProvider(now));

        var cancelled = await service.CancelReservationAsync(admin.Id, reservation.Id);
        Assert.Equal(ReservationStatus.Cancelled.ToString(), cancelled.ReservationStatus);
        Assert.Equal(PaymentStatus.Completed.ToString(), cancelled.PaymentStatus);
        Assert.True(cancelled.CredentialsAssigned);
        var cancelledJson = System.Text.Json.JsonSerializer.Serialize(cancelled);
        Assert.DoesNotContain("never-return-this-value", cancelledJson);
        Assert.DoesNotContain("assignedPassword", cancelledJson, StringComparison.OrdinalIgnoreCase);

        var repeat = await Assert.ThrowsAsync<ApiException>(() =>
            service.CancelReservationAsync(admin.Id, reservation.Id));
        Assert.Equal("ADMIN_RESERVATION_TRANSITION_INVALID", repeat.Code);
        Assert.Single(dbContext.AdminAuditEvents, item => item.Action == AdminAuditAction.ReservationCancelled);
        Assert.Single(dbContext.UserNotifications, item => item.Type == UserNotificationType.ReservationCancelled);
    }

    [Fact]
    public async Task BroadcastNotification_RequiresConfirmationAndTargetsCustomerAccounts()
    {
        await using var dbContext = TestDbFactory.Create();
        var (admin, _, _) = await SeedAsync(dbContext);
        var service = BuildControlService(dbContext, TimeProvider.System);
        var request = new AdminSendNotificationDto
        {
            RecipientScope = AdminNotificationRecipientScope.AllUsers.ToString(),
            Title = "Platform notice",
            Message = "A scheduled maintenance notice.",
            Category = "General"
        };

        var confirmation = await Assert.ThrowsAsync<ApiException>(() =>
            service.SendNotificationAsync(admin.Id, request));
        Assert.Equal("ADMIN_BROADCAST_CONFIRMATION_REQUIRED", confirmation.Code);
        Assert.Empty(dbContext.UserNotifications);

        request.ConfirmBroadcast = true;
        var campaign = await service.SendNotificationAsync(admin.Id, request);
        Assert.Equal(1, campaign.TargetCount);
        Assert.Single(dbContext.UserNotifications);
        Assert.DoesNotContain(dbContext.UserNotifications, item => item.UserId == admin.Id);
    }

    [Theory]
    [InlineData(typeof(AdminOperationsController))]
    [InlineData(typeof(AdminManagementController))]
    [InlineData(typeof(AdminServersController))]
    [InlineData(typeof(AdminSupportController))]
    public void AdminControllers_RequireExistingAdminRole(Type controllerType)
    {
        var authorize = controllerType.GetCustomAttribute<AuthorizeAttribute>();
        Assert.NotNull(authorize);
        Assert.Equal("Admin", authorize!.Roles);
    }

    private static AdminControlService BuildControlService(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        TimeProvider timeProvider,
        IUserNotificationService? notificationService = null)
    {
        notificationService ??= new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            timeProvider,
            NullLogger<UserNotificationService>.Instance);

        return new AdminControlService(
            new AdminControlRepository(dbContext),
            new ServerRepository(dbContext),
            new ReservationRepository(dbContext),
            notificationService,
            new BCryptPasswordHasher(),
            timeProvider);
    }

    private static ReservationService BuildReservationService(
        FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        return new ReservationService(
            new ReservationRepository(dbContext),
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            new UserNotificationService(
                new UserNotificationRepository(dbContext),
                new RecordingUserNotificationRealtimeNotifier(),
                TimeProvider.System,
                NullLogger<UserNotificationService>.Instance),
            TimeProvider.System);
    }

    private static async Task<(User Admin, User User, Server Server)> SeedAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var admin = new User
        {
            FullName = "Admin Operator",
            Email = $"admin-{Guid.NewGuid():N}@test.local",
            PasswordHash = "hash",
            Role = UserRole.Admin,
            IsEmailVerified = true,
            CreatedAt = DateTime.UtcNow
        };
        var user = new User
        {
            FullName = "Customer",
            Email = $"user-{Guid.NewGuid():N}@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            IsEmailVerified = true,
            CreatedAt = DateTime.UtcNow
        };
        var server = new Server
        {
            CPU = "AMD EPYC 9654",
            GPU = "NVIDIA H100 80GB",
            RAM = "256GB",
            Storage = "4TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 520_000m,
            PricePerDay = 9_360_000m,
            IsActive = true,
            OperationalStatus = ServerOperationalStatus.Available,
            FinderEligible = true,
            CpuCapabilityLevel = 100,
            GpuCapabilityLevel = 100,
            PerformanceTier = ServerPerformanceTier.Extreme
        };

        await dbContext.Users.AddRangeAsync(admin, user);
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();
        return (admin, user, server);
    }
}
