using AutoMapper;
using FinalMvcApp.Data;
using FinalMvcApp.Mappings;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

internal static class SupportTestFactory
{
    public static IMapper CreateMapper()
    {
        var configuration = new MapperConfiguration(
            config => config.AddProfile<MappingProfile>(),
            NullLoggerFactory.Instance);
        configuration.AssertConfigurationIsValid();
        return configuration.CreateMapper();
    }

    public static SupportService CreateSupportService(
        ApplicationDbContext dbContext,
        RecordingSupportNotifier? notifier = null,
        ISupportAiOrchestrator? aiOrchestrator = null)
    {
        return new SupportService(
            new SupportRepository(dbContext),
            notifier ?? new RecordingSupportNotifier(),
            aiOrchestrator ?? new NoOpSupportAiOrchestrator(),
            CreateMapper());
    }

    public static AdminSupportService CreateAdminService(
        ApplicationDbContext dbContext,
        RecordingSupportNotifier? notifier = null,
        ISupportAiOrchestrator? aiOrchestrator = null)
    {
        return new AdminSupportService(
            new SupportRepository(dbContext),
            new SupportQuickReplyRepository(dbContext),
            new UserRepository(dbContext),
            notifier ?? new RecordingSupportNotifier(),
            aiOrchestrator ?? new NoOpSupportAiOrchestrator(),
            new RecordingUserNotificationService(),
            CreateMapper());
    }

    public static async Task<User> AddUserAsync(
        ApplicationDbContext dbContext,
        string email,
        UserRole role = UserRole.User)
    {
        var user = new User
        {
            FullName = role == UserRole.Admin ? "Support Admin" : "Support User",
            Email = email,
            PasswordHash = "hash",
            Role = role,
            CreatedAt = DateTime.UtcNow
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.SaveChangesAsync();
        return user;
    }
}

internal sealed class RecordingUserNotificationService : IUserNotificationService
{
    public List<UserNotificationRequest> Requests { get; } = new();

    public Task<FinalMvcApp.DTOs.Common.CursorPageDto<FinalMvcApp.DTOs.Notifications.UserNotificationDto>> GetForUserAsync(
        int userId,
        FinalMvcApp.DTOs.Notifications.NotificationQueryDto query,
        CancellationToken cancellationToken = default)
        => throw new NotSupportedException();

    public Task<FinalMvcApp.DTOs.Notifications.NotificationUnreadCountDto> GetUnreadCountAsync(
        int userId,
        CancellationToken cancellationToken = default)
        => throw new NotSupportedException();

    public Task<FinalMvcApp.DTOs.Notifications.UserNotificationDto> MarkReadAsync(
        int userId,
        Guid notificationId,
        CancellationToken cancellationToken = default)
        => throw new NotSupportedException();

    public Task<FinalMvcApp.DTOs.Notifications.NotificationUnreadCountDto> MarkAllReadAsync(
        int userId,
        CancellationToken cancellationToken = default)
        => throw new NotSupportedException();

    public Task<FinalMvcApp.DTOs.Notifications.UserNotificationDto?> DispatchAsync(
        UserNotificationRequest request,
        CancellationToken cancellationToken = default)
    {
        Requests.Add(request);
        return Task.FromResult<FinalMvcApp.DTOs.Notifications.UserNotificationDto?>(null);
    }

    public Task<IReadOnlyList<FinalMvcApp.DTOs.Notifications.UserNotificationDto>> DispatchManyAsync(
        IEnumerable<UserNotificationRequest> requests,
        CancellationToken cancellationToken = default)
    {
        Requests.AddRange(requests);
        return Task.FromResult<IReadOnlyList<FinalMvcApp.DTOs.Notifications.UserNotificationDto>>([]);
    }

    public Task<bool> ExistsAsync(
        int userId,
        string deduplicationKey,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(false);
    }
}

internal sealed class NoOpSupportAiOrchestrator : ISupportAiOrchestrator
{
    public Task<FinalMvcApp.DTOs.Support.SupportAutomationResultDto> ProcessUserMessageAsync(
        Guid conversationId,
        Guid userMessageId,
        int? authenticatedUserId,
        CancellationToken cancellationToken = default)
    {
        _ = conversationId;
        _ = userMessageId;
        _ = authenticatedUserId;
        _ = cancellationToken;
        return Task.FromResult(new FinalMvcApp.DTOs.Support.SupportAutomationResultDto());
    }

    public Task<FinalMvcApp.DTOs.Support.SupportSuggestedReplyDto> GenerateAdminSuggestedReplyAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        _ = conversationId;
        _ = cancellationToken;
        return Task.FromResult(new FinalMvcApp.DTOs.Support.SupportSuggestedReplyDto
        {
            Draft = "Test suggestion",
            GeneratedAt = DateTime.UtcNow
        });
    }
}

internal sealed class RecordingSupportNotifier : ISupportRealtimeNotifier
{
    public List<(Guid ConversationId, string EventType)> Notifications { get; } = new();

    public Task PublishAsync(
        Guid conversationId,
        Guid? messageId,
        long? sequenceNumber,
        string eventType,
        int? ownerUserId,
        CancellationToken cancellationToken = default)
    {
        _ = messageId;
        _ = sequenceNumber;
        _ = ownerUserId;
        _ = cancellationToken;
        Notifications.Add((conversationId, eventType));
        return Task.CompletedTask;
    }
}
