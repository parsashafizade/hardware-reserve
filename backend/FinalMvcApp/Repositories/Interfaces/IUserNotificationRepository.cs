using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IUserNotificationRepository
{
    Task<IReadOnlyList<UserNotification>> GetForUserAsync(
        int userId,
        DateTime? cursorCreatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default);

    Task<int> GetUnreadCountAsync(int userId, CancellationToken cancellationToken = default);

    Task<UserNotification?> GetForUserByIdAsync(
        int userId,
        Guid notificationId,
        CancellationToken cancellationToken = default);

    Task<int> MarkAllReadAsync(
        int userId,
        DateTime readAt,
        CancellationToken cancellationToken = default);

    Task<UserNotification?> TryAddAsync(
        UserNotification notification,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<UserNotification>> TryAddRangeAsync(
        IReadOnlyCollection<UserNotification> notifications,
        CancellationToken cancellationToken = default);

    Task<bool> ExistsAsync(
        int userId,
        string deduplicationKey,
        CancellationToken cancellationToken = default);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
