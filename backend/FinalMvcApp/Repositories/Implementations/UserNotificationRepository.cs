using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class UserNotificationRepository : IUserNotificationRepository
{
    private readonly ApplicationDbContext _context;

    public UserNotificationRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<UserNotification>> GetForUserAsync(
        int userId,
        DateTime? cursorCreatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = _context.UserNotifications
            .AsNoTracking()
            .Where(notification => notification.UserId == userId);

        if (cursorCreatedAt.HasValue && cursorId.HasValue)
        {
            query = query.Where(notification => notification.CreatedAt < cursorCreatedAt.Value
                || (notification.CreatedAt == cursorCreatedAt.Value
                    && notification.Id.CompareTo(cursorId.Value) < 0));
        }

        return await query
            .OrderByDescending(notification => notification.CreatedAt)
            .ThenByDescending(notification => notification.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public Task<int> GetUnreadCountAsync(int userId, CancellationToken cancellationToken = default)
    {
        return _context.UserNotifications
            .AsNoTracking()
            .CountAsync(
                notification => notification.UserId == userId && notification.ReadAt == null,
                cancellationToken);
    }

    public Task<UserNotification?> GetForUserByIdAsync(
        int userId,
        Guid notificationId,
        CancellationToken cancellationToken = default)
    {
        return _context.UserNotifications.FirstOrDefaultAsync(
            notification => notification.Id == notificationId && notification.UserId == userId,
            cancellationToken);
    }

    public async Task<int> MarkAllReadAsync(
        int userId,
        DateTime readAt,
        CancellationToken cancellationToken = default)
    {
        var query = _context.UserNotifications
            .Where(notification => notification.UserId == userId && notification.ReadAt == null);

        if (_context.Database.IsRelational())
        {
            return await query.ExecuteUpdateAsync(
                setters => setters.SetProperty(notification => notification.ReadAt, readAt),
                cancellationToken);
        }

        var notifications = await query.ToListAsync(cancellationToken);
        foreach (var notification in notifications)
        {
            notification.ReadAt = readAt;
        }

        return await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<UserNotification?> TryAddAsync(
        UserNotification notification,
        CancellationToken cancellationToken = default)
    {
        if (await _context.UserNotifications.AnyAsync(
                item => item.DeduplicationKey == notification.DeduplicationKey,
                cancellationToken))
        {
            return null;
        }

        await _context.UserNotifications.AddAsync(notification, cancellationToken);

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
            return notification;
        }
        catch (DbUpdateException)
        {
            _context.Entry(notification).State = EntityState.Detached;

            if (await _context.UserNotifications
                    .AsNoTracking()
                    .AnyAsync(
                        item => item.DeduplicationKey == notification.DeduplicationKey,
                        cancellationToken))
            {
                return null;
            }

            throw;
        }
    }

    public async Task<IReadOnlyList<UserNotification>> TryAddRangeAsync(
        IReadOnlyCollection<UserNotification> notifications,
        CancellationToken cancellationToken = default)
    {
        if (notifications.Count == 0)
        {
            return [];
        }

        var candidates = notifications
            .GroupBy(notification => notification.DeduplicationKey)
            .Select(group => group.First())
            .ToList();
        var keys = candidates.Select(notification => notification.DeduplicationKey).ToList();
        var existingKeys = await _context.UserNotifications
            .AsNoTracking()
            .Where(notification => keys.Contains(notification.DeduplicationKey))
            .Select(notification => notification.DeduplicationKey)
            .ToListAsync(cancellationToken);
        var existing = existingKeys.ToHashSet(StringComparer.Ordinal);
        var pending = candidates
            .Where(notification => !existing.Contains(notification.DeduplicationKey))
            .ToList();

        if (pending.Count == 0)
        {
            return [];
        }

        await _context.UserNotifications.AddRangeAsync(pending, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
        return pending;
    }

    public Task<bool> ExistsAsync(
        int userId,
        string deduplicationKey,
        CancellationToken cancellationToken = default)
    {
        return _context.UserNotifications
            .AsNoTracking()
            .AnyAsync(
                notification => notification.UserId == userId
                    && notification.DeduplicationKey == deduplicationKey,
                cancellationToken);
    }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _context.SaveChangesAsync(cancellationToken);
    }
}
