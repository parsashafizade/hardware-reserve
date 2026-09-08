using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Notifications;

namespace FinalMvcApp.Services.Interfaces;

public interface IUserNotificationService
{
    Task<CursorPageDto<UserNotificationDto>> GetForUserAsync(
        int userId,
        NotificationQueryDto query,
        CancellationToken cancellationToken = default);

    Task<NotificationUnreadCountDto> GetUnreadCountAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<UserNotificationDto> MarkReadAsync(
        int userId,
        Guid notificationId,
        CancellationToken cancellationToken = default);

    Task<NotificationUnreadCountDto> MarkAllReadAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<UserNotificationDto?> DispatchAsync(
        UserNotificationRequest request,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<UserNotificationDto>> DispatchManyAsync(
        IEnumerable<UserNotificationRequest> requests,
        CancellationToken cancellationToken = default);

    Task<bool> ExistsAsync(
        int userId,
        string deduplicationKey,
        CancellationToken cancellationToken = default);
}
