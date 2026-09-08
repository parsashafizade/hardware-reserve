using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IAdminControlRepository
{
    Task<IReadOnlyList<ServerMaintenanceWindow>> GetMaintenanceWindowsAsync(int serverId, CancellationToken cancellationToken = default);

    Task<ServerMaintenanceWindow?> TryAddMaintenanceWindowAsync(ServerMaintenanceWindow window, CancellationToken cancellationToken = default);

    Task<ServerMaintenanceWindow?> GetMaintenanceWindowAsync(Guid windowId, CancellationToken cancellationToken = default);

    void RemoveMaintenanceWindow(ServerMaintenanceWindow window);

    Task AddCampaignAsync(AdminNotificationCampaign campaign, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<AdminNotificationCampaign> Items, int TotalCount)> GetCampaignsAsync(int page, int pageSize, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<int>> GetNotificationRecipientIdsAsync(IReadOnlyCollection<int>? userIds, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<UserNotification> Items, int TotalCount)> GetNotificationsAsync(
        UserNotificationSource? source,
        UserNotificationType? type,
        int? userId,
        bool? isRead,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<Reservation> Items, int TotalCount)> GetReservationsAsync(
        string? query,
        string? status,
        AdminAssignmentFilter? assignmentFilter,
        DateTime nowUtc,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<Reservation?> TryCancelReservationAsync(int reservationId, DateTime nowUtc, CancellationToken cancellationToken = default);

    Task<User?> GetUserAsync(int userId, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<User> Items, int TotalCount)> SearchUsersAsync(string? query, int page, int pageSize, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<AdminNotificationRecipientRecord> Items, int TotalCount)> SearchNotificationRecipientsAsync(string? query, int page, int pageSize, CancellationToken cancellationToken = default);

    Task<User?> TryCreateAdminAsync(User user, int actingAdminUserId, DateTime nowUtc, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetRecentReservationsForUserAsync(int userId, int take, CancellationToken cancellationToken = default);

    Task<(int Reservations, int ActiveReservations, int CompletedPayments, int SupportConversations, int UnreadNotifications)> GetUserCountsAsync(int userId, DateTime nowUtc, CancellationToken cancellationToken = default);

    Task<AdminDashboardOperationalCounts> GetOperationalCountsAsync(DateTime nowUtc, CancellationToken cancellationToken = default);

    Task AddAuditEventAsync(AdminAuditEvent auditEvent, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AdminAuditEvent>> GetRecentAuditEventsAsync(int take, CancellationToken cancellationToken = default);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
