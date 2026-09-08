using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

public class NotificationEventIntegrationTests
{
    [Fact]
    public async Task ReservationCreationAndPayment_CreateDurableNotifications()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "notification-flow@test.local");
        var server = await AddServerAsync(dbContext);
        var notificationService = BuildNotificationService(dbContext);
        var reservationService = new ReservationService(
            new ReservationRepository(dbContext),
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            notificationService,
            TimeProvider.System);
        var start = DateTime.UtcNow.AddDays(1);

        var created = await reservationService.CreateAsync(user.Id, new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(2)
        });

        var paymentService = new PaymentService(
            new ReservationRepository(dbContext),
            new PaymentRepository(dbContext),
            notificationService);
        await paymentService.PayReservationAsync(user.Id, created.ReservationId);

        var notifications = dbContext.UserNotifications
            .Where(notification => notification.UserId == user.Id)
            .ToList();
        Assert.Equal(2, notifications.Count);
        Assert.Contains(notifications, notification => notification.Type == UserNotificationType.ReservationCreated);
        Assert.Contains(notifications, notification => notification.Type == UserNotificationType.PaymentConfirmed);
        Assert.All(notifications, notification => Assert.Equal(created.ReservationId, notification.ReservationId));
    }

    [Fact]
    public async Task AdminReply_CreatesNotificationForAuthenticatedConversationOwnerOnly()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "support-notification@test.local");
        var admin = await SupportTestFactory.AddUserAsync(dbContext, "support-notification-admin@test.local", UserRole.Admin);
        var conversation = new SupportConversation
        {
            Id = Guid.NewGuid(),
            UserId = owner.Id,
            Title = "Provisioning question",
            Status = SupportConversationStatus.ADMIN_ACTIVE,
            AssignedAdminUserId = admin.Id,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            ReadState = new SupportConversationReadState()
        };
        await dbContext.SupportConversations.AddAsync(conversation);
        await dbContext.SaveChangesAsync();

        var service = new AdminSupportService(
            new SupportRepository(dbContext),
            new SupportQuickReplyRepository(dbContext),
            new UserRepository(dbContext),
            new RecordingSupportNotifier(),
            new NoOpSupportAiOrchestrator(),
            BuildNotificationService(dbContext),
            SupportTestFactory.CreateMapper());

        await service.SendMessageAsync(admin.Id, conversation.Id, new SendSupportMessageRequestDto
        {
            ClientMessageId = "admin-reply-1",
            Content = "Your service is being reviewed."
        });

        var notification = Assert.Single(dbContext.UserNotifications);
        Assert.Equal(owner.Id, notification.UserId);
        Assert.Equal(UserNotificationType.SupportReply, notification.Type);
        Assert.Equal(conversation.Id, notification.SupportConversationId);
    }

    private static UserNotificationService BuildNotificationService(
        FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        return new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            TimeProvider.System,
            NullLogger<UserNotificationService>.Instance);
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
}
