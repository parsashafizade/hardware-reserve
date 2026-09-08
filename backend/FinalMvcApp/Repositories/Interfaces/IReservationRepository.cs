using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IReservationRepository : IRepository<Reservation>
{
    Task<IReadOnlyList<Reservation>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetPaidByUserIdAsync(int userId, CancellationToken cancellationToken = default);

    Task<Reservation?> GetByIdForUserAsync(
        int reservationId,
        int userId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetRecentByUserIdAsync(
        int userId,
        int take,
        bool paidOnly,
        CancellationToken cancellationToken = default);

    Task<Reservation?> GetDashboardPrimaryAsync(
        int userId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default);

    Task<ReservationDashboardCounts> GetDashboardCountsAsync(
        int userId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> SearchForUserAsync(
        int userId,
        string normalizedQuery,
        int? reservationId,
        ReservationStatus? status,
        int take,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetFutureForServerAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ReservationAvailabilityBlock>> GetAvailabilityBlocksAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetAllWithDetailsAsync(CancellationToken cancellationToken = default);

    Task<ReservationCredentialAssignmentResult?> AssignCredentialsAsync(
        int reservationId,
        string assignedIp,
        string assignedUsername,
        string assignedPassword,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetPendingServiceDetailsNotificationsAsync(
        int take,
        CancellationToken cancellationToken = default);

    Task MarkServiceDetailsNotificationDeliveredAsync(
        int reservationId,
        int serviceDetailsVersion,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Reservation>> GetPaidForNotificationWindowAsync(
        DateTime nowUtc,
        DateTime latestStartUtc,
        CancellationToken cancellationToken = default);

    Task MarkStartedNotificationDeliveredAsync(
        int reservationId,
        CancellationToken cancellationToken = default);

    Task MarkCompletedNotificationDeliveredAsync(
        int reservationId,
        CancellationToken cancellationToken = default);

    Task<bool> HasOverlappingReservationAsync(
        int serverId,
        DateTime startTime,
        DateTime endTime,
        int? ignoredReservationId = null,
        CancellationToken cancellationToken = default);

    Task<bool> HasAvailabilityConflictAsync(
        int serverId,
        DateTime startTime,
        DateTime endTime,
        int? ignoredReservationId = null,
        CancellationToken cancellationToken = default);

    Task<bool> TryAddIfAvailableAsync(
        Reservation reservation,
        CancellationToken cancellationToken = default);
}
