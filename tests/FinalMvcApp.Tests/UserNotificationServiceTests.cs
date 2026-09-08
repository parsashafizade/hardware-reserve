using FinalMvcApp.DTOs.Notifications;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

public class UserNotificationServiceTests
{
    [Fact]
    public async Task NotificationAccess_IsOwnerScoped_AndReadStatePersists()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "notification-owner@test.local");
        var other = await SupportTestFactory.AddUserAsync(dbContext, "notification-other@test.local");
        var (service, realtime) = BuildService(dbContext);

        var created = await service.DispatchAsync(new UserNotificationRequest(
            owner.Id,
            UserNotificationType.ReservationCreated,
            "test:owner-scoped",
            "NVIDIA A100",
            ReservationId: null));

        Assert.NotNull(created);
        Assert.Single(realtime.Deliveries);
        Assert.Equal(owner.Id, realtime.Deliveries[0].UserId);
        Assert.Equal(1, (await service.GetUnreadCountAsync(owner.Id)).UnreadCount);
        Assert.Empty((await service.GetForUserAsync(other.Id, new NotificationQueryDto())).Items);

        await Assert.ThrowsAsync<KeyNotFoundException>(() =>
            service.MarkReadAsync(other.Id, created!.Id));

        var read = await service.MarkReadAsync(owner.Id, created!.Id);
        Assert.NotNull(read.ReadAt);
        Assert.Equal(0, (await service.GetUnreadCountAsync(owner.Id)).UnreadCount);
    }

    [Fact]
    public async Task DispatchAsync_DeduplicatesLogicalEvent()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "notification-dedupe@test.local");
        var (service, realtime) = BuildService(dbContext);
        var request = new UserNotificationRequest(
            user.Id,
            UserNotificationType.PaymentConfirmed,
            "reservation:42:payment-confirmed",
            "RTX 4090",
            42);

        var first = await service.DispatchAsync(request);
        var duplicate = await service.DispatchAsync(request);

        Assert.NotNull(first);
        Assert.Null(duplicate);
        Assert.Single(dbContext.UserNotifications);
        Assert.Single(realtime.Deliveries);
    }

    [Fact]
    public async Task GetForUserAsync_UsesStableCursorPagination()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "notification-page@test.local");
        var (service, _) = BuildService(dbContext);

        for (var index = 0; index < 5; index++)
        {
            await service.DispatchAsync(new UserNotificationRequest(
                user.Id,
                UserNotificationType.ReservationCreated,
                $"pagination:{index}"));
        }

        var first = await service.GetForUserAsync(user.Id, new NotificationQueryDto { PageSize = 2 });
        var second = await service.GetForUserAsync(user.Id, new NotificationQueryDto
        {
            PageSize = 2,
            Cursor = first.NextCursor
        });

        Assert.Equal(2, first.Items.Count);
        Assert.True(first.HasMore);
        Assert.NotNull(first.NextCursor);
        Assert.Equal(2, second.Items.Count);
        Assert.DoesNotContain(second.Items, item => first.Items.Any(previous => previous.Id == item.Id));
    }

    [Fact]
    public async Task MarkAllRead_OnlyChangesCurrentUsersNotifications()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "notification-all@test.local");
        var other = await SupportTestFactory.AddUserAsync(dbContext, "notification-all-other@test.local");
        var (service, _) = BuildService(dbContext);

        await service.DispatchAsync(new UserNotificationRequest(
            owner.Id,
            UserNotificationType.ReservationCreated,
            "mark-all:owner"));
        await service.DispatchAsync(new UserNotificationRequest(
            other.Id,
            UserNotificationType.ReservationCreated,
            "mark-all:other"));

        await service.MarkAllReadAsync(owner.Id);

        Assert.Equal(0, (await service.GetUnreadCountAsync(owner.Id)).UnreadCount);
        Assert.Equal(1, (await service.GetUnreadCountAsync(other.Id)).UnreadCount);
    }

    [Fact]
    public async Task ReservationReminderProcessing_IsTimeAwareAndIdempotent()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "reminders@test.local");
        var server = await AddServerAsync(dbContext);
        var now = new DateTime(2026, 8, 20, 10, 0, 0, DateTimeKind.Utc);

        var completed = NewPaidReservation(
            user.Id,
            server.Id,
            now.AddHours(-2),
            now.AddMinutes(-10));
        completed.StartedNotificationDelivered = true;
        dbContext.Reservations.AddRange(
            NewPaidReservation(user.Id, server.Id, now.AddMinutes(20), now.AddHours(2)),
            NewPaidReservation(user.Id, server.Id, now.AddHours(-1), now.AddMinutes(5)),
            completed);
        await dbContext.SaveChangesAsync();

        var (notificationService, _) = BuildService(dbContext);
        var reservationRepository = new ReservationRepository(dbContext);
        var reminders = new ReservationReminderService(
            reservationRepository,
            notificationService,
            new ServiceDetailsNotificationService(
                reservationRepository,
                notificationService,
                TimeProvider.System,
                NullLogger<ServiceDetailsNotificationService>.Instance));

        await reminders.ProcessDueAsync(now);
        await reminders.ProcessDueAsync(now);

        var types = dbContext.UserNotifications.Select(notification => notification.Type).ToList();
        Assert.Equal(4, types.Count);
        Assert.Contains(UserNotificationType.ReservationStartsSoon, types);
        Assert.Contains(UserNotificationType.ReservationStarted, types);
        Assert.Contains(UserNotificationType.ReservationEndsSoon, types);
        Assert.Contains(UserNotificationType.ReservationCompleted, types);
    }

    [Fact]
    public async Task LifecycleStartAndCompletion_AreOwnerLinkedAndRemainSingleAfterServiceRestart()
    {
        await using var dbContext = TestDbFactory.Create();
        var activeOwner = await SupportTestFactory.AddUserAsync(
            dbContext,
            "lifecycle-active@test.local");
        var completedOwner = await SupportTestFactory.AddUserAsync(
            dbContext,
            "lifecycle-completed@test.local");
        var server = await AddServerAsync(dbContext);
        var now = new DateTime(2026, 8, 23, 10, 0, 0, DateTimeKind.Utc);
        var active = NewPaidReservation(
            activeOwner.Id,
            server.Id,
            now.AddMinutes(-5),
            now.AddHours(2));
        var completed = NewPaidReservation(
            completedOwner.Id,
            server.Id,
            now.AddHours(-2),
            now.AddMinutes(-5));
        completed.StartedNotificationDelivered = true;
        dbContext.Reservations.AddRange(active, completed);
        await dbContext.SaveChangesAsync();

        var firstNotificationService = BuildService(dbContext).Service;
        await BuildReminder(dbContext, firstNotificationService).ProcessDueAsync(now);

        // A new service graph over the same durable database is a restart proxy.
        var restartedNotificationService = BuildService(dbContext).Service;
        await BuildReminder(dbContext, restartedNotificationService).ProcessDueAsync(now);

        var started = Assert.Single(
            dbContext.UserNotifications,
            item => item.Type == UserNotificationType.ReservationStarted);
        Assert.Equal(active.Id, started.ReservationId);
        Assert.Equal(activeOwner.Id, started.UserId);

        var ended = Assert.Single(
            dbContext.UserNotifications,
            item => item.Type == UserNotificationType.ReservationCompleted);
        Assert.Equal(completed.Id, ended.ReservationId);
        Assert.Equal(completedOwner.Id, ended.UserId);
        Assert.Equal(2, dbContext.UserNotifications.Count());
    }

    [Fact]
    public async Task LifecycleRecovery_AfterExtendedOutage_BackfillsEachLogicalEventOnce()
    {
        var databaseName = $"lifecycle-restart-{Guid.NewGuid():N}";
        var options = new DbContextOptionsBuilder<FinalMvcApp.Data.ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName)
            .Options;
        var now = new DateTime(2026, 8, 23, 10, 0, 0, DateTimeKind.Utc);
        int ownerId;
        int reservationId;

        await using (var setup = new FinalMvcApp.Data.ApplicationDbContext(options))
        {
            var owner = await SupportTestFactory.AddUserAsync(
                setup,
                "lifecycle-extended-outage@test.local");
            var server = await AddServerAsync(setup);
            var reservation = NewPaidReservation(
                owner.Id,
                server.Id,
                now.AddDays(-3),
                now.AddDays(-2));
            setup.Reservations.Add(reservation);
            await setup.SaveChangesAsync();
            ownerId = owner.Id;
            reservationId = reservation.Id;
        }

        await using (var firstRun = new FinalMvcApp.Data.ApplicationDbContext(options))
        {
            var notificationService = BuildService(firstRun).Service;
            await BuildReminder(firstRun, notificationService).ProcessDueAsync(now);
        }

        await using (var restarted = new FinalMvcApp.Data.ApplicationDbContext(options))
        {
            var notificationService = BuildService(restarted).Service;
            await BuildReminder(restarted, notificationService).ProcessDueAsync(now.AddHours(1));
        }

        await using var verification = new FinalMvcApp.Data.ApplicationDbContext(options);
        var notifications = await verification.UserNotifications
            .Where(item => item.ReservationId == reservationId)
            .ToListAsync();
        Assert.Single(
            notifications,
            item => item.Type == UserNotificationType.ReservationStarted
                && item.UserId == ownerId);
        Assert.Single(
            notifications,
            item => item.Type == UserNotificationType.ReservationCompleted
                && item.UserId == ownerId);
        var persisted = await verification.Reservations.FindAsync(reservationId);
        Assert.True(persisted!.StartedNotificationDelivered);
        Assert.True(persisted.CompletedNotificationDelivered);
    }

    private static (UserNotificationService Service, RecordingUserNotificationRealtimeNotifier Realtime)
        BuildService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var realtime = new RecordingUserNotificationRealtimeNotifier();
        return (
            new UserNotificationService(
                new UserNotificationRepository(dbContext),
                realtime,
                TimeProvider.System,
                NullLogger<UserNotificationService>.Instance),
            realtime);
    }

    private static ReservationReminderService BuildReminder(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        IUserNotificationService notificationService)
    {
        var reservationRepository = new ReservationRepository(dbContext);
        return new ReservationReminderService(
            reservationRepository,
            notificationService,
            new ServiceDetailsNotificationService(
                reservationRepository,
                notificationService,
                TimeProvider.System,
                NullLogger<ServiceDetailsNotificationService>.Instance));
    }

    private static async Task<Server> AddServerAsync(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var server = new Server
        {
            CPU = "AMD EPYC",
            GPU = "NVIDIA A100",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 75_000m,
            PricePerDay = 1_350_000m,
            IsActive = true
        };
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();
        return server;
    }

    private static Reservation NewPaidReservation(
        int userId,
        int serverId,
        DateTime startTime,
        DateTime endTime)
    {
        return new Reservation
        {
            UserId = userId,
            ServerId = serverId,
            StartTime = startTime,
            EndTime = endTime,
            TotalPrice = 100_000m,
            Status = ReservationStatus.Paid
        };
    }
}

internal sealed class RecordingUserNotificationRealtimeNotifier : IUserNotificationRealtimeNotifier
{
    public List<(int UserId, UserNotificationDto Notification)> Deliveries { get; } = new();

    public Task PublishAsync(
        int userId,
        UserNotificationDto notification,
        CancellationToken cancellationToken = default)
    {
        Deliveries.Add((userId, notification));
        return Task.CompletedTask;
    }

    public Task PublishReadStateAsync(
        int userId,
        NotificationReadStateRealtimeDto state,
        CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }
}
