using FinalMvcApp.DTOs.Notifications;

namespace FinalMvcApp.Services.Interfaces;

public interface IUserNotificationRealtimeNotifier
{
    Task PublishAsync(
        int userId,
        UserNotificationDto notification,
        CancellationToken cancellationToken = default);

    Task PublishReadStateAsync(
        int userId,
        NotificationReadStateRealtimeDto state,
        CancellationToken cancellationToken = default);
}
