using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class ReservationRepository : Repository<Reservation>, IReservationRepository
{
    private const int ReservationLockNamespace = 20260820;
    private const int CredentialAssignmentLockNamespace = 20260823;

    public ReservationRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public override async Task<Reservation?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(reservation => reservation.User)
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .FirstOrDefaultAsync(reservation => reservation.Id == id, cancellationToken);
    }

    public async Task<IReadOnlyList<Reservation>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .Where(reservation => reservation.UserId == userId)
            .OrderByDescending(reservation => reservation.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Reservation>> GetPaidByUserIdAsync(int userId, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(reservation => reservation.Server)
            .Where(reservation => reservation.UserId == userId && reservation.Status == ReservationStatus.Paid)
            .OrderByDescending(reservation => reservation.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task<Reservation?> GetByIdForUserAsync(
        int reservationId,
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .FirstOrDefaultAsync(
                reservation => reservation.Id == reservationId && reservation.UserId == userId,
                cancellationToken);
    }

    public async Task<IReadOnlyList<Reservation>> GetRecentByUserIdAsync(
        int userId,
        int take,
        bool paidOnly,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .Where(reservation => reservation.UserId == userId);

        if (paidOnly)
        {
            query = query.Where(reservation => reservation.Status == ReservationStatus.Paid);
        }

        return await query
            .OrderByDescending(reservation => reservation.StartTime)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<Reservation?> GetDashboardPrimaryAsync(
        int userId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .Where(reservation => reservation.UserId == userId
                && reservation.Status != ReservationStatus.Cancelled)
            .OrderBy(reservation =>
                reservation.Status == ReservationStatus.PendingPayment
                    ? 0
                    : reservation.Status == ReservationStatus.Paid
                        && reservation.StartTime <= nowUtc
                        && reservation.EndTime > nowUtc
                            ? 1
                            : reservation.Status == ReservationStatus.Paid
                                && reservation.StartTime > nowUtc
                                    ? 2
                                    : 3)
            .ThenBy(reservation =>
                reservation.Status == ReservationStatus.Paid
                    && reservation.EndTime <= nowUtc
                        ? nowUtc
                        : reservation.Status == ReservationStatus.Paid
                            && reservation.StartTime <= nowUtc
                            && reservation.EndTime > nowUtc
                                ? reservation.EndTime
                                : reservation.StartTime)
            .ThenByDescending(reservation => reservation.EndTime)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<ReservationDashboardCounts> GetDashboardCountsAsync(
        int userId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Where(reservation => reservation.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new ReservationDashboardCounts
            {
                TotalReservations = group.Count(),
                PendingPayment = group.Count(reservation =>
                    reservation.Status == ReservationStatus.PendingPayment),
                Active = group.Count(reservation =>
                    reservation.Status == ReservationStatus.Paid
                    && reservation.StartTime <= nowUtc
                    && reservation.EndTime > nowUtc),
                Upcoming = group.Count(reservation =>
                    reservation.Status == ReservationStatus.Paid
                    && reservation.StartTime > nowUtc),
                Completed = group.Count(reservation =>
                    reservation.Status == ReservationStatus.Paid
                    && reservation.EndTime <= nowUtc)
            })
            .SingleOrDefaultAsync(cancellationToken)
            ?? new ReservationDashboardCounts();
    }

    public async Task<IReadOnlyList<Reservation>> SearchForUserAsync(
        int userId,
        string normalizedQuery,
        int? reservationId,
        ReservationStatus? status,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .Where(reservation => reservation.UserId == userId
                && ((reservationId.HasValue && reservation.Id == reservationId.Value)
                    || (status.HasValue && reservation.Status == status.Value)
                    || reservation.Server.CPU.ToLower().Contains(normalizedQuery)
                    || reservation.Server.GPU.ToLower().Contains(normalizedQuery)
                    || reservation.Server.RAM.ToLower().Contains(normalizedQuery)
                    || reservation.Server.Storage.ToLower().Contains(normalizedQuery)
                    || reservation.Server.OS.ToLower().Contains(normalizedQuery)))
            .OrderBy(reservation =>
                reservationId.HasValue && reservation.Id == reservationId.Value ? 0 : 1)
            .ThenByDescending(reservation => reservation.StartTime)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Reservation>> GetFutureForServerAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(reservation => reservation.ServerId == serverId
                && reservation.Status != ReservationStatus.Cancelled
                && reservation.EndTime > fromUtc
                && reservation.StartTime < toUtc)
            .OrderBy(reservation => reservation.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ReservationAvailabilityBlock>> GetAvailabilityBlocksAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default)
    {
        var reservations = await DbSet
            .AsNoTracking()
            .Where(reservation => reservation.ServerId == serverId
                && reservation.Status != ReservationStatus.Cancelled
                && reservation.EndTime > fromUtc
                && reservation.StartTime < toUtc)
            .Select(reservation => new ReservationAvailabilityBlock(
                reservation.Id,
                reservation.StartTime,
                reservation.EndTime,
                false))
            .ToListAsync(cancellationToken);

        var maintenance = await Context.ServerMaintenanceWindows
            .AsNoTracking()
            .Where(window => window.ServerId == serverId
                && window.EndTime > fromUtc
                && window.StartTime < toUtc)
            .Select(window => new ReservationAvailabilityBlock(
                null,
                window.StartTime,
                window.EndTime,
                true))
            .ToListAsync(cancellationToken);

        return reservations
            .Concat(maintenance)
            .OrderBy(block => block.StartTime)
            .ThenBy(block => block.EndTime)
            .ToList();
    }

    public async Task<IReadOnlyList<Reservation>> GetAllWithDetailsAsync(CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(reservation => reservation.User)
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .OrderByDescending(reservation => reservation.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task<ReservationCredentialAssignmentResult?> AssignCredentialsAsync(
        int reservationId,
        string assignedIp,
        string assignedUsername,
        string assignedPassword,
        CancellationToken cancellationToken = default)
    {
        if (!Context.Database.IsRelational())
        {
            return await AssignCredentialsCoreAsync(
                reservationId,
                assignedIp,
                assignedUsername,
                assignedPassword,
                cancellationToken);
        }

        await using var transaction = await Context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await Context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({CredentialAssignmentLockNamespace}, {reservationId})",
                cancellationToken);

            var result = await AssignCredentialsCoreAsync(
                reservationId,
                assignedIp,
                assignedUsername,
                assignedPassword,
                cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public async Task<IReadOnlyList<Reservation>> GetPaidForNotificationWindowAsync(
        DateTime nowUtc,
        DateTime latestStartUtc,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Where(reservation => reservation.Status == ReservationStatus.Paid
                && reservation.StartTime <= latestStartUtc
                && (reservation.EndTime > nowUtc
                    || !reservation.StartedNotificationDelivered
                    || !reservation.CompletedNotificationDelivered))
            .OrderBy(reservation => reservation.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task MarkStartedNotificationDeliveredAsync(
        int reservationId,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.Where(reservation =>
            reservation.Id == reservationId
            && !reservation.StartedNotificationDelivered);

        if (Context.Database.IsRelational())
        {
            await query.ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    reservation => reservation.StartedNotificationDelivered,
                    true),
                cancellationToken);
            return;
        }

        var reservation = await query.SingleOrDefaultAsync(cancellationToken);
        if (reservation is not null)
        {
            reservation.StartedNotificationDelivered = true;
            await Context.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task MarkCompletedNotificationDeliveredAsync(
        int reservationId,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.Where(reservation =>
            reservation.Id == reservationId
            && !reservation.CompletedNotificationDelivered);

        if (Context.Database.IsRelational())
        {
            await query.ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    reservation => reservation.CompletedNotificationDelivered,
                    true),
                cancellationToken);
            return;
        }

        var reservation = await query.SingleOrDefaultAsync(cancellationToken);
        if (reservation is not null)
        {
            reservation.CompletedNotificationDelivered = true;
            await Context.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task<ReservationCredentialAssignmentResult?> AssignCredentialsCoreAsync(
        int reservationId,
        string assignedIp,
        string assignedUsername,
        string assignedPassword,
        CancellationToken cancellationToken)
    {
        var reservation = await GetByIdAsync(reservationId, cancellationToken);
        if (reservation is null)
        {
            return null;
        }

        if (reservation.Status != ReservationStatus.Paid)
        {
            return new ReservationCredentialAssignmentResult(
                reservation,
                IsEligible: false,
                Changed: false,
                WasPreviouslyAssigned: HasAssignedCredentials(reservation),
                ServiceDetailsVersion: reservation.ServiceDetailsVersion);
        }

        var wasPreviouslyAssigned = HasAssignedCredentials(reservation);
        var changed = !string.Equals(reservation.AssignedIp, assignedIp, StringComparison.Ordinal)
            || !string.Equals(reservation.AssignedUsername, assignedUsername, StringComparison.Ordinal)
            || !string.Equals(reservation.AssignedPassword, assignedPassword, StringComparison.Ordinal);

        if (changed)
        {
            reservation.AssignedIp = assignedIp;
            reservation.AssignedUsername = assignedUsername;
            reservation.AssignedPassword = assignedPassword;
            reservation.ServiceDetailsVersion = checked(reservation.ServiceDetailsVersion + 1);
            await Context.SaveChangesAsync(cancellationToken);
        }

        return new ReservationCredentialAssignmentResult(
            reservation,
            IsEligible: true,
            Changed: changed,
            WasPreviouslyAssigned: wasPreviouslyAssigned,
            ServiceDetailsVersion: reservation.ServiceDetailsVersion);
    }

    public async Task<IReadOnlyList<Reservation>> GetPendingServiceDetailsNotificationsAsync(
        int take,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(reservation => reservation.Server)
            .Where(reservation =>
                reservation.ServiceDetailsVersion > reservation.ServiceDetailsNotifiedVersion)
            .OrderBy(reservation => reservation.Id)
            .Take(Math.Clamp(take, 1, 500))
            .ToListAsync(cancellationToken);
    }

    public async Task MarkServiceDetailsNotificationDeliveredAsync(
        int reservationId,
        int serviceDetailsVersion,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.Where(reservation =>
            reservation.Id == reservationId
            && reservation.ServiceDetailsVersion >= serviceDetailsVersion
            && reservation.ServiceDetailsNotifiedVersion < serviceDetailsVersion);

        if (Context.Database.IsRelational())
        {
            await query.ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    reservation => reservation.ServiceDetailsNotifiedVersion,
                    serviceDetailsVersion),
                cancellationToken);
            return;
        }

        var reservation = await query.SingleOrDefaultAsync(cancellationToken);
        if (reservation is not null)
        {
            reservation.ServiceDetailsNotifiedVersion = serviceDetailsVersion;
            await Context.SaveChangesAsync(cancellationToken);
        }
    }

    private static bool HasAssignedCredentials(Reservation reservation) =>
        !string.IsNullOrWhiteSpace(reservation.AssignedIp)
        && !string.IsNullOrWhiteSpace(reservation.AssignedUsername)
        && !string.IsNullOrWhiteSpace(reservation.AssignedPassword);

    public async Task<bool> HasOverlappingReservationAsync(
        int serverId,
        DateTime startTime,
        DateTime endTime,
        int? ignoredReservationId = null,
        CancellationToken cancellationToken = default)
    {
        return await DbSet.AnyAsync(
            reservation => reservation.ServerId == serverId
                && reservation.Status != ReservationStatus.Cancelled
                && startTime < reservation.EndTime
                && endTime > reservation.StartTime
                && (!ignoredReservationId.HasValue || reservation.Id != ignoredReservationId.Value),
            cancellationToken);
    }

    public async Task<bool> HasAvailabilityConflictAsync(
        int serverId,
        DateTime startTime,
        DateTime endTime,
        int? ignoredReservationId = null,
        CancellationToken cancellationToken = default)
    {
        var serverAvailable = await Context.Servers
            .AsNoTracking()
            .AnyAsync(
                server => server.Id == serverId
                    && server.IsActive
                    && server.OperationalStatus == ServerOperationalStatus.Available,
                cancellationToken);

        if (!serverAvailable)
        {
            return true;
        }

        if (await HasOverlappingReservationAsync(
                serverId,
                startTime,
                endTime,
                ignoredReservationId,
                cancellationToken))
        {
            return true;
        }

        return await Context.ServerMaintenanceWindows.AnyAsync(
            window => window.ServerId == serverId
                && startTime < window.EndTime
                && endTime > window.StartTime,
            cancellationToken);
    }

    public async Task<bool> TryAddIfAvailableAsync(
        Reservation reservation,
        CancellationToken cancellationToken = default)
    {
        if (!Context.Database.IsRelational())
        {
            if (await HasAvailabilityConflictAsync(
                    reservation.ServerId,
                    reservation.StartTime,
                    reservation.EndTime,
                    cancellationToken: cancellationToken))
            {
                return false;
            }

            await DbSet.AddAsync(reservation, cancellationToken);
            await Context.SaveChangesAsync(cancellationToken);
            return true;
        }

        await using var transaction = await Context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // Serialize reservation creation for this server across all API instances.
            await Context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({ReservationLockNamespace}, {reservation.ServerId})",
                cancellationToken);

            if (await HasAvailabilityConflictAsync(
                    reservation.ServerId,
                    reservation.StartTime,
                    reservation.EndTime,
                    cancellationToken: cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return false;
            }

            await DbSet.AddAsync(reservation, cancellationToken);
            await Context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return true;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }
}
