using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class SupportRepository : ISupportRepository
{
    private readonly ApplicationDbContext _context;

    public SupportRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task AddConversationAsync(SupportConversation conversation, CancellationToken cancellationToken = default)
    {
        await _context.SupportConversations.AddAsync(conversation, cancellationToken);
    }

    public async Task AddAnonymousSessionAsync(AnonymousSupportSession session, CancellationToken cancellationToken = default)
    {
        await _context.AnonymousSupportSessions.AddAsync(session, cancellationToken);
    }

    public async Task<AnonymousSupportSession?> GetAnonymousSessionByTokenHashAsync(
        string tokenHash,
        CancellationToken cancellationToken = default)
    {
        return await _context.AnonymousSupportSessions
            .FirstOrDefaultAsync(session => session.TokenHash == tokenHash, cancellationToken);
    }

    public async Task<SupportConversation?> GetConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await ConversationQuery(asTracking: false)
            .FirstOrDefaultAsync(conversation => conversation.Id == conversationId, cancellationToken);
    }

    public async Task<bool> UserOwnsConversationAsync(
        int userId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await _context.SupportConversations
            .AsNoTracking()
            .AnyAsync(
                conversation => conversation.Id == conversationId && conversation.UserId == userId,
                cancellationToken);
    }

    public async Task<IReadOnlyList<SupportConversation>> GetUserConversationsAsync(
        int userId,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = ConversationQuery(asTracking: false)
            .Where(conversation => conversation.UserId == userId);

        query = ApplyConversationCursor(query, cursorUpdatedAt, cursorId);

        return await query
            .OrderByDescending(conversation => conversation.UpdatedAt)
            .ThenByDescending(conversation => conversation.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<SupportConversation>> GetAnonymousConversationsAsync(
        Guid anonymousSessionId,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = ConversationQuery(asTracking: false)
            .Where(conversation => conversation.AnonymousSessionId == anonymousSessionId);

        query = ApplyConversationCursor(query, cursorUpdatedAt, cursorId);

        return await query
            .OrderByDescending(conversation => conversation.UpdatedAt)
            .ThenByDescending(conversation => conversation.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<SupportConversation>> GetAdminConversationsAsync(
        SupportConversationStatus? status,
        string? category,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = ConversationQuery(asTracking: false);

        if (status.HasValue)
        {
            query = query.Where(conversation => conversation.Status == status.Value);
        }

        if (!string.IsNullOrWhiteSpace(category))
        {
            var normalizedCategory = category.Trim().ToLowerInvariant();
            query = query.Where(conversation => conversation.Category != null
                && conversation.Category.ToLower() == normalizedCategory);
        }

        query = ApplyConversationCursor(query, cursorUpdatedAt, cursorId);

        return await query
            .OrderByDescending(conversation => conversation.UpdatedAt)
            .ThenByDescending(conversation => conversation.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<SupportMessage>> GetMessagesAsync(
        Guid conversationId,
        long? beforeSequence,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = _context.SupportMessages
            .AsNoTracking()
            .Where(message => message.ConversationId == conversationId);

        if (beforeSequence.HasValue)
        {
            query = query.Where(message => message.SequenceNumber < beforeSequence.Value);
        }

        return await query
            .OrderByDescending(message => message.SequenceNumber)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<SupportMessage?> GetMessageByClientIdAsync(
        Guid conversationId,
        SupportParticipantType senderType,
        string clientMessageId,
        CancellationToken cancellationToken = default)
    {
        return await _context.SupportMessages
            .AsNoTracking()
            .FirstOrDefaultAsync(
                message => message.ConversationId == conversationId
                    && message.SenderType == senderType
                    && message.ClientMessageId == clientMessageId,
                cancellationToken);
    }

    public async Task AddMessageAsync(SupportMessage message, CancellationToken cancellationToken = default)
    {
        await _context.SupportMessages.AddAsync(message, cancellationToken);
    }

    public async Task<SupportMessage?> GetMessageByIdAsync(
        Guid messageId,
        CancellationToken cancellationToken = default)
    {
        return await _context.SupportMessages
            .AsNoTracking()
            .FirstOrDefaultAsync(message => message.Id == messageId, cancellationToken);
    }

    public async Task<SupportAiProcessing?> GetAiProcessingByUserMessageIdAsync(
        Guid userMessageId,
        bool asTracking,
        CancellationToken cancellationToken = default)
    {
        var query = _context.SupportAiProcessings
            .Where(processing => processing.UserMessageId == userMessageId);

        return await (asTracking ? query : query.AsNoTracking())
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task AddAiProcessingAsync(
        SupportAiProcessing processing,
        CancellationToken cancellationToken = default)
    {
        await _context.SupportAiProcessings.AddAsync(processing, cancellationToken);
    }

    public async Task<IReadOnlyList<SupportConversationEvent>> GetEventsAsync(
        Guid conversationId,
        DateTime? cursorOccurredAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default)
    {
        var query = _context.SupportConversationEvents
            .AsNoTracking()
            .Where(supportEvent => supportEvent.ConversationId == conversationId);

        if (cursorOccurredAt.HasValue && cursorId.HasValue)
        {
            query = query.Where(supportEvent => supportEvent.OccurredAt < cursorOccurredAt.Value
                || (supportEvent.OccurredAt == cursorOccurredAt.Value
                    && supportEvent.Id.CompareTo(cursorId.Value) < 0));
        }

        return await query
            .OrderByDescending(supportEvent => supportEvent.OccurredAt)
            .ThenByDescending(supportEvent => supportEvent.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> GetUserUnreadCountAsync(int userId, CancellationToken cancellationToken = default)
    {
        return await _context.SupportConversations
            .AsNoTracking()
            .Where(conversation => conversation.UserId == userId)
            .Select(conversation => conversation.ReadState.UserUnreadCount)
            .SumAsync(cancellationToken);
    }

    public async Task<int> GetAnonymousUnreadCountAsync(
        Guid anonymousSessionId,
        CancellationToken cancellationToken = default)
    {
        return await _context.SupportConversations
            .AsNoTracking()
            .Where(conversation => conversation.AnonymousSessionId == anonymousSessionId)
            .Select(conversation => conversation.ReadState.UserUnreadCount)
            .SumAsync(cancellationToken);
    }

    public async Task<int> GetAdminUnreadCountAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SupportConversationReadStates
            .AsNoTracking()
            .SumAsync(readState => readState.AdminUnreadCount, cancellationToken);
    }

    public async Task<TResult> ExecuteWithConversationLockAsync<TResult>(
        Guid conversationId,
        Func<SupportConversation, CancellationToken, Task<TResult>> operation,
        CancellationToken cancellationToken = default)
    {
        if (!_context.Database.IsRelational())
        {
            var inMemoryConversation = await GetTrackedConversationAsync(conversationId, false, cancellationToken)
                ?? throw new KeyNotFoundException("Support conversation not found.");
            var inMemoryResult = await operation(inMemoryConversation, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            return inMemoryResult;
        }

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            var conversation = await GetTrackedConversationAsync(conversationId, true, cancellationToken)
                ?? throw new KeyNotFoundException("Support conversation not found.");
            var result = await operation(conversation, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw;
        }
    }

    public async Task AddEventAsync(SupportConversationEvent supportEvent, CancellationToken cancellationToken = default)
    {
        await _context.SupportConversationEvents.AddAsync(supportEvent, cancellationToken);
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<SupportConversation> ConversationQuery(bool asTracking)
    {
        var query = _context.SupportConversations
            .Include(conversation => conversation.ReadState)
            .Include(conversation => conversation.User)
            .Include(conversation => conversation.AnonymousSession);

        return asTracking ? query : query.AsNoTracking();
    }

    private async Task<SupportConversation?> GetTrackedConversationAsync(
        Guid conversationId,
        bool useRowLock,
        CancellationToken cancellationToken)
    {
        IQueryable<SupportConversation> query = useRowLock
            ? _context.SupportConversations.FromSqlInterpolated(
                $"SELECT * FROM \"SupportConversations\" WHERE \"Id\" = {conversationId} FOR UPDATE")
            : _context.SupportConversations;

        return await query
            .Include(conversation => conversation.ReadState)
            .Include(conversation => conversation.User)
            .Include(conversation => conversation.AnonymousSession)
            .FirstOrDefaultAsync(conversation => conversation.Id == conversationId, cancellationToken);
    }

    private static IQueryable<SupportConversation> ApplyConversationCursor(
        IQueryable<SupportConversation> query,
        DateTime? cursorUpdatedAt,
        Guid? cursorId)
    {
        if (cursorUpdatedAt.HasValue && cursorId.HasValue)
        {
            query = query.Where(conversation => conversation.UpdatedAt < cursorUpdatedAt.Value
                || (conversation.UpdatedAt == cursorUpdatedAt.Value && conversation.Id.CompareTo(cursorId.Value) < 0));
        }

        return query;
    }
}
