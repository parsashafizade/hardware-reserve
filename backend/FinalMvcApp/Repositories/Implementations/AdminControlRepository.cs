using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class AdminControlRepository : IAdminControlRepository
{
    private const int ServerAvailabilityLockNamespace = 20260820;
    private readonly ApplicationDbContext _context;

    public AdminControlRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<ServerMaintenanceWindow>> GetMaintenanceWindowsAsync(
        int serverId,
        CancellationToken cancellationToken = default)
    {
        return await _context.ServerMaintenanceWindows
            .AsNoTracking()
            .Where(window => window.ServerId == serverId)
            .OrderBy(window => window.StartTime)
            .ToListAsync(cancellationToken);
    }

    public async Task<ServerMaintenanceWindow?> TryAddMaintenanceWindowAsync(
        ServerMaintenanceWindow window,
        CancellationToken cancellationToken = default)
    {
        if (!_context.Database.IsRelational())
        {
            return await TryAddMaintenanceCoreAsync(window, cancellationToken);
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({ServerAvailabilityLockNamespace}, {window.ServerId})",
                cancellationToken);

            var result = await TryAddMaintenanceCoreAsync(window, cancellationToken);
            if (result is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public Task<ServerMaintenanceWindow?> GetMaintenanceWindowAsync(
        Guid windowId,
        CancellationToken cancellationToken = default)
    {
        return _context.ServerMaintenanceWindows.FirstOrDefaultAsync(
            window => window.Id == windowId,
            cancellationToken);
    }

    public void RemoveMaintenanceWindow(ServerMaintenanceWindow window)
    {
        _context.ServerMaintenanceWindows.Remove(window);
    }

    public async Task AddCampaignAsync(
        AdminNotificationCampaign campaign,
        CancellationToken cancellationToken = default)
    {
        await _context.AdminNotificationCampaigns.AddAsync(campaign, cancellationToken);
    }

    public async Task<(IReadOnlyList<AdminNotificationCampaign> Items, int TotalCount)> GetCampaignsAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = _context.AdminNotificationCampaigns
            .AsNoTracking()
            .Include(campaign => campaign.RecipientUser);

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(campaign => campaign.CreatedAt)
            .ThenByDescending(campaign => campaign.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<IReadOnlyList<int>> GetNotificationRecipientIdsAsync(
        IReadOnlyCollection<int>? userIds,
        CancellationToken cancellationToken = default)
    {
        var query = _context.Users.AsNoTracking();
        if (userIds is { Count: > 0 })
        {
            query = query.Where(user => userIds.Contains(user.Id));
        }
        else
        {
            query = query.Where(user => user.Role == UserRole.User);
        }

        return await query
            .OrderBy(user => user.Id)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);
    }

    public async Task<(IReadOnlyList<UserNotification> Items, int TotalCount)> GetNotificationsAsync(
        UserNotificationSource? source,
        UserNotificationType? type,
        int? userId,
        bool? isRead,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var notifications = _context.UserNotifications
            .AsNoTracking()
            .Include(notification => notification.User)
            .AsQueryable();

        if (source.HasValue)
        {
            notifications = notifications.Where(notification => notification.Source == source.Value);
        }

        if (type.HasValue)
        {
            notifications = notifications.Where(notification => notification.Type == type.Value);
        }

        if (userId.HasValue)
        {
            notifications = notifications.Where(notification => notification.UserId == userId.Value);
        }

        if (isRead.HasValue)
        {
            notifications = isRead.Value
                ? notifications.Where(notification => notification.ReadAt != null)
                : notifications.Where(notification => notification.ReadAt == null);
        }

        var totalCount = await notifications.CountAsync(cancellationToken);
        var items = await notifications
            .OrderByDescending(notification => notification.CreatedAt)
            .ThenByDescending(notification => notification.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<(IReadOnlyList<Reservation> Items, int TotalCount)> GetReservationsAsync(
        string? query,
        string? status,
        AdminAssignmentFilter? assignmentFilter,
        DateTime nowUtc,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var reservations = _context.Reservations
            .AsNoTracking()
            .Include(reservation => reservation.User)
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query))
        {
            var normalized = query.Trim().ToLowerInvariant();
            var hasId = int.TryParse(normalized.TrimStart('#'), out var id);
            reservations = reservations.Where(reservation =>
                (hasId && (reservation.Id == id || reservation.UserId == id || reservation.ServerId == id))
                || reservation.User.FullName.ToLower().Contains(normalized)
                || reservation.User.Email.ToLower().Contains(normalized)
                || reservation.Server.CPU.ToLower().Contains(normalized)
                || reservation.Server.GPU.ToLower().Contains(normalized));
        }

        reservations = status?.Trim().ToLowerInvariant() switch
        {
            "pendingpayment" => reservations.Where(item => item.Status == ReservationStatus.PendingPayment),
            "active" => reservations.Where(item => item.Status == ReservationStatus.Paid && item.StartTime <= nowUtc && item.EndTime > nowUtc),
            "upcoming" => reservations.Where(item => item.Status == ReservationStatus.Paid && item.StartTime > nowUtc),
            "completed" => reservations.Where(item => item.Status == ReservationStatus.Paid && item.EndTime <= nowUtc),
            "cancelled" => reservations.Where(item => item.Status == ReservationStatus.Cancelled),
            "paid" => reservations.Where(item => item.Status == ReservationStatus.Paid),
            _ => reservations
        };

        reservations = assignmentFilter switch
        {
            AdminAssignmentFilter.NeedsAssignment => ApplyNeedsAssignmentFilter(reservations, nowUtc),
            AdminAssignmentFilter.Assigned => reservations.Where(item =>
                item.Status == ReservationStatus.Paid
                && !string.IsNullOrWhiteSpace(item.AssignedIp)
                && !string.IsNullOrWhiteSpace(item.AssignedUsername)
                && !string.IsNullOrWhiteSpace(item.AssignedPassword)),
            _ => reservations
        };

        var totalCount = await reservations.CountAsync(cancellationToken);
        var items = await reservations
            .OrderByDescending(reservation => reservation.StartTime)
            .ThenByDescending(reservation => reservation.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<User?> TryCreateAdminAsync(
        User user,
        int actingAdminUserId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        if (!_context.Database.IsRelational())
        {
            return await TryCreateAdminCoreAsync(user, actingAdminUserId, nowUtc, cancellationToken);
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            var created = await TryCreateAdminCoreAsync(
                user,
                actingAdminUserId,
                nowUtc,
                cancellationToken);
            if (created is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            await transaction.CommitAsync(cancellationToken);
            return created;
        }
        catch (DbUpdateException)
        {
            await transaction.RollbackAsync(CancellationToken.None);
            _context.ChangeTracker.Clear();
            if (await _context.Users.AsNoTracking().AnyAsync(
                    existing => existing.Email == user.Email,
                    CancellationToken.None))
            {
                return null;
            }

            throw;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public async Task<Reservation?> TryCancelReservationAsync(
        int reservationId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        if (!_context.Database.IsRelational())
        {
            return await TryCancelReservationCoreAsync(reservationId, nowUtc, cancellationToken);
        }

        var serverId = await _context.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => (int?)reservation.ServerId)
            .SingleOrDefaultAsync(cancellationToken);
        if (!serverId.HasValue)
        {
            return null;
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({ServerAvailabilityLockNamespace}, {serverId.Value})",
                cancellationToken);

            var reservation = await TryCancelReservationCoreAsync(reservationId, nowUtc, cancellationToken);
            if (reservation is null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            await transaction.CommitAsync(cancellationToken);
            return reservation;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public Task<User?> GetUserAsync(int userId, CancellationToken cancellationToken = default)
    {
        return _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(user => user.Id == userId, cancellationToken);
    }

    public async Task<(IReadOnlyList<User> Items, int TotalCount)> SearchUsersAsync(
        string? query,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var users = _context.Users.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(query))
        {
            var normalized = query.Trim().ToLowerInvariant();
            users = users.Where(user =>
                user.FullName.ToLower().Contains(normalized)
                || user.Email.ToLower().Contains(normalized));
        }

        var totalCount = await users.CountAsync(cancellationToken);
        var items = await users
            .OrderByDescending(user => user.CreatedAt)
            .ThenByDescending(user => user.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        return (items, totalCount);
    }

    public async Task<(IReadOnlyList<AdminNotificationRecipientRecord> Items, int TotalCount)> SearchNotificationRecipientsAsync(
        string? query,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var users = _context.Users.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(query))
        {
            var normalized = query.Trim().ToLowerInvariant();
            users = users.Where(user =>
                user.FullName.ToLower().Contains(normalized)
                || user.Email.ToLower().Contains(normalized));
        }

        var totalCount = await users.CountAsync(cancellationToken);
        var items = await users
            .OrderByDescending(user => user.CreatedAt)
            .ThenByDescending(user => user.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(user => new AdminNotificationRecipientRecord(
                user.Id,
                user.FullName,
                user.Email))
            .ToListAsync(cancellationToken);
        return (items, totalCount);
    }

    public async Task<IReadOnlyList<Reservation>> GetRecentReservationsForUserAsync(
        int userId,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await _context.Reservations
            .AsNoTracking()
            .Include(reservation => reservation.User)
            .Include(reservation => reservation.Server)
            .Include(reservation => reservation.Payment)
            .Where(reservation => reservation.UserId == userId)
            .OrderByDescending(reservation => reservation.StartTime)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<(int Reservations, int ActiveReservations, int CompletedPayments, int SupportConversations, int UnreadNotifications)> GetUserCountsAsync(
        int userId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var reservations = await _context.Reservations
            .AsNoTracking()
            .CountAsync(reservation => reservation.UserId == userId, cancellationToken);
        var active = await _context.Reservations
            .AsNoTracking()
            .CountAsync(reservation => reservation.UserId == userId
                && reservation.Status == ReservationStatus.Paid
                && reservation.StartTime <= nowUtc
                && reservation.EndTime > nowUtc,
                cancellationToken);
        var payments = await _context.Payments
            .AsNoTracking()
            .CountAsync(payment => payment.Reservation.UserId == userId && payment.Status == PaymentStatus.Completed, cancellationToken);
        var conversations = await _context.SupportConversations
            .AsNoTracking()
            .CountAsync(conversation => conversation.UserId == userId, cancellationToken);
        var unread = await _context.UserNotifications
            .AsNoTracking()
            .CountAsync(notification => notification.UserId == userId && notification.ReadAt == null, cancellationToken);

        return (reservations, active, payments, conversations, unread);
    }

    public async Task<AdminDashboardOperationalCounts> GetOperationalCountsAsync(
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var soonStart = nowUtc.AddMinutes(30);
        var soonEnd = nowUtc.AddHours(1);

        var active = await _context.Reservations.CountAsync(
            item => item.Status == ReservationStatus.Paid && item.StartTime <= nowUtc && item.EndTime > nowUtc,
            cancellationToken);
        var upcoming = await _context.Reservations.CountAsync(
            item => item.Status == ReservationStatus.Paid && item.StartTime > nowUtc,
            cancellationToken);
        var startingSoon = await _context.Reservations.CountAsync(
            item => item.Status == ReservationStatus.Paid && item.StartTime > nowUtc && item.StartTime <= soonStart,
            cancellationToken);
        var endingSoon = await _context.Reservations.CountAsync(
            item => item.Status == ReservationStatus.Paid && item.EndTime > nowUtc && item.EndTime <= soonEnd,
            cancellationToken);
        var pendingPayments = await _context.Reservations.CountAsync(
            item => item.Status == ReservationStatus.PendingPayment,
            cancellationToken);
        var unavailableServers = await _context.Servers.CountAsync(
            server => !server.IsActive || server.OperationalStatus != ServerOperationalStatus.Available,
            cancellationToken);
        var maintenanceServers = await _context.Servers.CountAsync(
            server => server.OperationalStatus == ServerOperationalStatus.Maintenance
                || server.MaintenanceWindows.Any(window => window.StartTime <= nowUtc && window.EndTime > nowUtc),
            cancellationToken);
        var waitingSupport = await _context.SupportConversations.CountAsync(
            conversation => conversation.Status == SupportConversationStatus.WAITING_FOR_ADMIN,
            cancellationToken);
        var pendingAssignments = await ApplyNeedsAssignmentFilter(
                _context.Reservations.AsNoTracking(),
                nowUtc)
            .CountAsync(cancellationToken);
        var supportAttention = await _context.SupportConversations
            .AsNoTracking()
            .CountAsync(
                conversation => conversation.Status == SupportConversationStatus.WAITING_FOR_ADMIN
                    || (conversation.Status == SupportConversationStatus.ADMIN_ACTIVE
                        && conversation.ReadState.AdminUnreadCount > 0),
                cancellationToken);

        return new AdminDashboardOperationalCounts(
            active,
            upcoming,
            startingSoon,
            endingSoon,
            pendingPayments,
            unavailableServers,
            maintenanceServers,
            waitingSupport,
            pendingAssignments,
            supportAttention);
    }

    public async Task AddAuditEventAsync(
        AdminAuditEvent auditEvent,
        CancellationToken cancellationToken = default)
    {
        await _context.AdminAuditEvents.AddAsync(auditEvent, cancellationToken);
    }

    public async Task<IReadOnlyList<AdminAuditEvent>> GetRecentAuditEventsAsync(
        int take,
        CancellationToken cancellationToken = default)
    {
        return await _context.AdminAuditEvents
            .AsNoTracking()
            .OrderByDescending(auditEvent => auditEvent.CreatedAt)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _context.SaveChangesAsync(cancellationToken);
    }

    private async Task<ServerMaintenanceWindow?> TryAddMaintenanceCoreAsync(
        ServerMaintenanceWindow window,
        CancellationToken cancellationToken)
    {
        var serverExists = await _context.Servers.AnyAsync(
            server => server.Id == window.ServerId && server.IsActive,
            cancellationToken);
        if (!serverExists)
        {
            return null;
        }

        var overlapsMaintenance = await _context.ServerMaintenanceWindows.AnyAsync(
            existing => existing.ServerId == window.ServerId
                && window.StartTime < existing.EndTime
                && window.EndTime > existing.StartTime,
            cancellationToken);
        var overlapsReservation = await _context.Reservations.AnyAsync(
            reservation => reservation.ServerId == window.ServerId
                && reservation.Status != ReservationStatus.Cancelled
                && window.StartTime < reservation.EndTime
                && window.EndTime > reservation.StartTime,
            cancellationToken);

        if (overlapsMaintenance || overlapsReservation)
        {
            return null;
        }

        await _context.ServerMaintenanceWindows.AddAsync(window, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
        return window;
    }

    private async Task<User?> TryCreateAdminCoreAsync(
        User user,
        int actingAdminUserId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        if (await _context.Users.AnyAsync(existing => existing.Email == user.Email, cancellationToken))
        {
            return null;
        }

        await _context.Users.AddAsync(user, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
        await _context.AdminAuditEvents.AddAsync(new AdminAuditEvent
        {
            Id = Guid.NewGuid(),
            AdminUserId = actingAdminUserId,
            Action = AdminAuditAction.AdminAccountCreated,
            EntityType = "User",
            EntityId = user.Id.ToString(),
            Details = $"Created admin user #{user.Id}.",
            CreatedAt = nowUtc
        }, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
        return user;
    }

    private static IQueryable<Reservation> ApplyNeedsAssignmentFilter(
        IQueryable<Reservation> reservations,
        DateTime nowUtc)
    {
        return reservations.Where(item =>
            item.Status == ReservationStatus.Paid
            && item.EndTime > nowUtc
            && (string.IsNullOrWhiteSpace(item.AssignedIp)
                || string.IsNullOrWhiteSpace(item.AssignedUsername)
                || string.IsNullOrWhiteSpace(item.AssignedPassword)));
    }

    private async Task<Reservation?> TryCancelReservationCoreAsync(
        int reservationId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var reservation = await _context.Reservations
            .Include(item => item.User)
            .Include(item => item.Server)
            .Include(item => item.Payment)
            .FirstOrDefaultAsync(
                item => item.Id == reservationId
                    && item.Status != ReservationStatus.Cancelled
                    && item.EndTime > nowUtc,
                cancellationToken);
        if (reservation is null)
        {
            return null;
        }

        reservation.Status = ReservationStatus.Cancelled;
        await _context.SaveChangesAsync(cancellationToken);
        return reservation;
    }
}
