using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Notifications;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;
using FluentValidation;
using FluentValidation.Results;

namespace FinalMvcApp.Services.Implementations;

public class UserNotificationService : IUserNotificationService
{
    private readonly IUserNotificationRepository _notificationRepository;
    private readonly IUserNotificationRealtimeNotifier _realtimeNotifier;
    private readonly TimeProvider _timeProvider;
    private readonly ILogger<UserNotificationService> _logger;

    public UserNotificationService(
        IUserNotificationRepository notificationRepository,
        IUserNotificationRealtimeNotifier realtimeNotifier,
        TimeProvider timeProvider,
        ILogger<UserNotificationService> logger)
    {
        _notificationRepository = notificationRepository;
        _realtimeNotifier = realtimeNotifier;
        _timeProvider = timeProvider;
        _logger = logger;
    }

    public async Task<CursorPageDto<UserNotificationDto>> GetForUserAsync(
        int userId,
        NotificationQueryDto query,
        CancellationToken cancellationToken = default)
    {
        if (!SupportCursorCodec.TryDecodeConversation(
                query.Cursor,
                out var cursorCreatedAt,
                out var cursorId))
        {
            throw new ValidationException([
                new ValidationFailure(nameof(query.Cursor), "Cursor is invalid.")
            ]);
        }

        var notifications = await _notificationRepository.GetForUserAsync(
            userId,
            cursorCreatedAt,
            cursorId,
            query.PageSize + 1,
            cancellationToken);

        var hasMore = notifications.Count > query.PageSize;
        var selected = notifications.Take(query.PageSize).ToList();
        var last = selected.LastOrDefault();

        return new CursorPageDto<UserNotificationDto>
        {
            Items = selected.Select(Map).ToList(),
            HasMore = hasMore,
            NextCursor = hasMore && last is not null
                ? SupportCursorCodec.EncodeConversation(last.CreatedAt, last.Id)
                : null
        };
    }

    public async Task<NotificationUnreadCountDto> GetUnreadCountAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return new NotificationUnreadCountDto
        {
            UnreadCount = await _notificationRepository.GetUnreadCountAsync(userId, cancellationToken)
        };
    }

    public async Task<UserNotificationDto> MarkReadAsync(
        int userId,
        Guid notificationId,
        CancellationToken cancellationToken = default)
    {
        var notification = await _notificationRepository.GetForUserByIdAsync(
            userId,
            notificationId,
            cancellationToken)
            ?? throw new KeyNotFoundException("Notification not found.");

        if (!notification.ReadAt.HasValue)
        {
            notification.ReadAt = _timeProvider.GetUtcNow().UtcDateTime;
            await _notificationRepository.SaveChangesAsync(cancellationToken);
            await PublishReadStateAsync(userId, notification.Id, cancellationToken);
        }

        return Map(notification);
    }

    public async Task<NotificationUnreadCountDto> MarkAllReadAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        await _notificationRepository.MarkAllReadAsync(
            userId,
            _timeProvider.GetUtcNow().UtcDateTime,
            cancellationToken);

        await PublishReadStateAsync(userId, null, cancellationToken);
        return new NotificationUnreadCountDto { UnreadCount = 0 };
    }

    public async Task<UserNotificationDto?> DispatchAsync(
        UserNotificationRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var notification = new UserNotification
            {
                Id = Guid.NewGuid(),
                UserId = request.UserId,
                Type = request.Type,
                Source = request.Source,
                DeduplicationKey = request.DeduplicationKey.Trim(),
                ResourceLabel = NormalizeLabel(request.ResourceLabel),
                Title = NormalizeText(request.Title, 120),
                Message = NormalizeText(request.Message, 1000),
                ReservationId = request.ReservationId,
                SupportConversationId = request.SupportConversationId,
                AdminCampaignId = request.AdminCampaignId,
                CreatedByAdminUserId = request.CreatedByAdminUserId,
                EventTime = request.EventTime,
                CreatedAt = _timeProvider.GetUtcNow().UtcDateTime
            };

            var created = await _notificationRepository.TryAddAsync(notification, cancellationToken);
            if (created is null)
            {
                return null;
            }

            var dto = Map(created);
            try
            {
                await _realtimeNotifier.PublishAsync(request.UserId, dto, CancellationToken.None);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                // Persistence remains authoritative when realtime delivery is unavailable.
                _logger.LogWarning(
                    exception,
                    "Could not publish notification {NotificationId} to user {UserId}",
                    created.Id,
                    request.UserId);
            }
            return dto;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Notifications must never roll back a completed reservation, payment, or support reply.
            _logger.LogError(
                exception,
                "Could not persist notification type {NotificationType} for user {UserId}",
                request.Type,
                request.UserId);
            return null;
        }
    }

    public async Task<IReadOnlyList<UserNotificationDto>> DispatchManyAsync(
        IEnumerable<UserNotificationRequest> requests,
        CancellationToken cancellationToken = default)
    {
        var createdAt = _timeProvider.GetUtcNow().UtcDateTime;
        var notifications = requests.Select(request => new UserNotification
        {
            Id = Guid.NewGuid(),
            UserId = request.UserId,
            Type = request.Type,
            Source = request.Source,
            DeduplicationKey = request.DeduplicationKey.Trim(),
            ResourceLabel = NormalizeLabel(request.ResourceLabel),
            Title = NormalizeText(request.Title, 120),
            Message = NormalizeText(request.Message, 1000),
            ReservationId = request.ReservationId,
            SupportConversationId = request.SupportConversationId,
            AdminCampaignId = request.AdminCampaignId,
            CreatedByAdminUserId = request.CreatedByAdminUserId,
            EventTime = request.EventTime,
            CreatedAt = createdAt
        }).ToList();

        var created = await _notificationRepository.TryAddRangeAsync(notifications, cancellationToken);
        var response = new List<UserNotificationDto>(created.Count);
        foreach (var notification in created)
        {
            var dto = Map(notification);
            response.Add(dto);
            try
            {
                await _realtimeNotifier.PublishAsync(notification.UserId, dto, CancellationToken.None);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                _logger.LogWarning(
                    exception,
                    "Could not publish notification {NotificationId} to user {UserId}",
                    notification.Id,
                    notification.UserId);
            }
        }
        return response;
    }

    public Task<bool> ExistsAsync(
        int userId,
        string deduplicationKey,
        CancellationToken cancellationToken = default)
    {
        return _notificationRepository.ExistsAsync(
            userId,
            deduplicationKey.Trim(),
            cancellationToken);
    }

    private static string? NormalizeLabel(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= 160 ? trimmed : trimmed[..160];
    }

    private static string? NormalizeText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    private async Task PublishReadStateAsync(
        int userId,
        Guid? notificationId,
        CancellationToken cancellationToken)
    {
        var unreadCount = await _notificationRepository.GetUnreadCountAsync(userId, cancellationToken);
        await _realtimeNotifier.PublishReadStateAsync(
            userId,
            new NotificationReadStateRealtimeDto
            {
                EventId = Guid.NewGuid(),
                NotificationId = notificationId,
                UnreadCount = unreadCount,
                OccurredAt = _timeProvider.GetUtcNow().UtcDateTime
            },
            CancellationToken.None);
    }

    private static UserNotificationDto Map(UserNotification notification)
    {
        return new UserNotificationDto
        {
            Id = notification.Id,
            Type = notification.Type.ToString(),
            Source = notification.Source.ToString(),
            ResourceLabel = notification.ResourceLabel,
            Title = notification.Title,
            Message = notification.Message,
            ReservationId = notification.ReservationId,
            SupportConversationId = notification.SupportConversationId,
            EventTime = notification.EventTime,
            CreatedAt = notification.CreatedAt,
            ReadAt = notification.ReadAt
        };
    }
}
