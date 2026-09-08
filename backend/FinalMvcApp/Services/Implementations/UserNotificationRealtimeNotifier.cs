using FinalMvcApp.DTOs.Notifications;
using FinalMvcApp.Hubs;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace FinalMvcApp.Services.Implementations;

public class UserNotificationRealtimeNotifier : IUserNotificationRealtimeNotifier
{
    public const string ClientEventName = "NotificationEvent";
    public const string ReadStateClientEventName = "NotificationStateEvent";
    private readonly IHubContext<SupportHub> _hubContext;
    private readonly ILogger<UserNotificationRealtimeNotifier> _logger;

    public UserNotificationRealtimeNotifier(
        IHubContext<SupportHub> hubContext,
        ILogger<UserNotificationRealtimeNotifier> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task PublishAsync(
        int userId,
        UserNotificationDto notification,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await _hubContext.Clients
                .Group(SupportHubGroups.User(userId))
                .SendAsync(ClientEventName, notification, cancellationToken);
        }
        catch (Exception exception)
        {
            // Persistence is authoritative; a disconnected client reconciles through HTTP.
            _logger.LogWarning(
                exception,
                "Notification realtime delivery failed for notification {NotificationId}",
                notification.Id);
        }
    }

    public async Task PublishReadStateAsync(
        int userId,
        NotificationReadStateRealtimeDto state,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await _hubContext.Clients
                .Group(SupportHubGroups.User(userId))
                .SendAsync(ReadStateClientEventName, state, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Notification read-state realtime delivery failed for user {UserId}",
                userId);
        }
    }
}
