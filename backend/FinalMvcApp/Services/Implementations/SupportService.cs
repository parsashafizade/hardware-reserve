using AutoMapper;
using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Mappings;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;
using FluentValidation;
using FluentValidation.Results;

namespace FinalMvcApp.Services.Implementations;

public class SupportService : ISupportService
{
    private static readonly TimeSpan AnonymousSessionLifetime = TimeSpan.FromDays(30);
    private readonly ISupportRepository _supportRepository;
    private readonly ISupportRealtimeNotifier _realtimeNotifier;
    private readonly ISupportAiOrchestrator _aiOrchestrator;
    private readonly IMapper _mapper;

    public SupportService(
        ISupportRepository supportRepository,
        ISupportRealtimeNotifier realtimeNotifier,
        ISupportAiOrchestrator aiOrchestrator,
        IMapper mapper)
    {
        _supportRepository = supportRepository;
        _realtimeNotifier = realtimeNotifier;
        _aiOrchestrator = aiOrchestrator;
        _mapper = mapper;
    }

    public async Task<AnonymousSupportSessionDto> CreateAnonymousSessionAsync(
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var token = AnonymousSupportToken.Create();
        var session = new AnonymousSupportSession
        {
            Id = Guid.NewGuid(),
            TokenHash = AnonymousSupportToken.Hash(token),
            CreatedAt = now,
            ExpiresAt = now.Add(AnonymousSessionLifetime),
            LastSeenAt = now
        };

        await _supportRepository.AddAnonymousSessionAsync(session, cancellationToken);
        await _supportRepository.SaveChangesAsync(cancellationToken);

        return new AnonymousSupportSessionDto
        {
            SessionToken = token,
            ExpiresAt = session.ExpiresAt
        };
    }

    public async Task<SupportConversationSummaryDto> CreateForUserAsync(
        int userId,
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken = default)
    {
        return await CreateConversationAsync(
            userId,
            null,
            request,
            SupportAuditActorType.User,
            cancellationToken);
    }

    public async Task<SupportConversationSummaryDto> CreateForAnonymousAsync(
        string sessionToken,
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);

        return await CreateConversationAsync(
            null,
            session.Id,
            request,
            SupportAuditActorType.Anonymous,
            cancellationToken);
    }

    public async Task<CursorPageDto<SupportConversationSummaryDto>> GetForUserAsync(
        int userId,
        SupportConversationQueryDto query,
        CancellationToken cancellationToken = default)
    {
        DecodeConversationCursor(query.Cursor, out var cursorUpdatedAt, out var cursorId);
        var conversations = await _supportRepository.GetUserConversationsAsync(
            userId,
            cursorUpdatedAt,
            cursorId,
            query.PageSize + 1,
            cancellationToken);

        return BuildConversationPage(conversations, query.PageSize);
    }

    public async Task<CursorPageDto<SupportConversationSummaryDto>> GetForAnonymousAsync(
        string sessionToken,
        SupportConversationQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);
        DecodeConversationCursor(query.Cursor, out var cursorUpdatedAt, out var cursorId);

        var conversations = await _supportRepository.GetAnonymousConversationsAsync(
            session.Id,
            cursorUpdatedAt,
            cursorId,
            query.PageSize + 1,
            cancellationToken);

        await _supportRepository.SaveChangesAsync(cancellationToken);
        return BuildConversationPage(conversations, query.PageSize);
    }

    public async Task<SupportMessageHistoryDto> GetMessagesForUserAsync(
        int userId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var conversation = await GetConversationAsync(conversationId, cancellationToken);
        EnsureUserOwns(conversation, userId);
        return await BuildMessageHistoryAsync(conversation, query, cancellationToken);
    }

    public async Task<SupportMessageHistoryDto> GetMessagesForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);
        var conversation = await GetConversationAsync(conversationId, cancellationToken);
        EnsureAnonymousOwns(conversation, session.Id);

        var result = await BuildMessageHistoryAsync(conversation, query, cancellationToken);
        await _supportRepository.SaveChangesAsync(cancellationToken);
        return result;
    }

    public async Task<SendSupportMessageResponseDto> SendForUserAsync(
        int userId,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default)
    {
        return await SendUserMessageAsync(
            conversationId,
            request,
            conversation => EnsureUserOwns(conversation, userId),
            userId,
            SupportAuditActorType.User,
            cancellationToken);
    }

    public async Task<SendSupportMessageResponseDto> SendForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);

        return await SendUserMessageAsync(
            conversationId,
            request,
            conversation => EnsureAnonymousOwns(conversation, session.Id),
            null,
            SupportAuditActorType.Anonymous,
            cancellationToken);
    }

    public async Task<SupportConversationSummaryDto> RequestAdminForUserAsync(
        int userId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await RequestAdminAsync(
            conversationId,
            conversation => EnsureUserOwns(conversation, userId),
            userId,
            SupportAuditActorType.User,
            cancellationToken);
    }

    public async Task<SupportConversationSummaryDto> RequestAdminForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);

        return await RequestAdminAsync(
            conversationId,
            conversation => EnsureAnonymousOwns(conversation, session.Id),
            null,
            SupportAuditActorType.Anonymous,
            cancellationToken);
    }

    public async Task<SupportUnreadCountDto> MarkReadForUserAsync(
        int userId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await MarkReadAsync(
            conversationId,
            conversation => EnsureUserOwns(conversation, userId),
            userId,
            () => _supportRepository.GetUserUnreadCountAsync(userId, cancellationToken),
            cancellationToken);
    }

    public async Task<SupportUnreadCountDto> MarkReadForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);

        return await MarkReadAsync(
            conversationId,
            conversation => EnsureAnonymousOwns(conversation, session.Id),
            null,
            () => _supportRepository.GetAnonymousUnreadCountAsync(session.Id, cancellationToken),
            cancellationToken);
    }

    public async Task<SupportUnreadCountDto> GetUnreadCountForUserAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return new SupportUnreadCountDto
        {
            UnreadMessages = await _supportRepository.GetUserUnreadCountAsync(userId, cancellationToken)
        };
    }

    public async Task<SupportUnreadCountDto> GetUnreadCountForAnonymousAsync(
        string sessionToken,
        CancellationToken cancellationToken = default)
    {
        var session = await GetActiveAnonymousSessionAsync(sessionToken, cancellationToken);
        TouchSession(session);
        var unreadCount = await _supportRepository.GetAnonymousUnreadCountAsync(session.Id, cancellationToken);
        await _supportRepository.SaveChangesAsync(cancellationToken);

        return new SupportUnreadCountDto
        {
            UnreadMessages = unreadCount
        };
    }

    public async Task<bool> CanSubscribeAsync(
        int userId,
        bool isAdmin,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        if (isAdmin)
        {
            return await _supportRepository.GetConversationAsync(conversationId, cancellationToken) is not null;
        }

        return await _supportRepository.UserOwnsConversationAsync(userId, conversationId, cancellationToken);
    }

    private async Task<SupportConversationSummaryDto> CreateConversationAsync(
        int? userId,
        Guid? anonymousSessionId,
        CreateSupportConversationRequestDto request,
        SupportAuditActorType actorType,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var conversation = new SupportConversation
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            AnonymousSessionId = anonymousSessionId,
            Title = SupportDomain.NormalizeOptional(request.Title) ?? "Support conversation",
            Category = SupportDomain.NormalizeOptional(request.Category),
            Status = SupportConversationStatus.AI_ACTIVE,
            CreatedAt = now,
            UpdatedAt = now,
            ReadState = new SupportConversationReadState()
        };

        conversation.Events.Add(SupportDomain.CreateEvent(
            conversation.Id,
            SupportAuditEventType.ConversationCreated,
            actorType,
            userId,
            null,
            SupportConversationStatus.AI_ACTIVE,
            now));

        await _supportRepository.AddConversationAsync(conversation, cancellationToken);
        await _supportRepository.SaveChangesAsync(cancellationToken);

        await _realtimeNotifier.PublishAsync(
            conversation.Id,
            null,
            null,
            "CONVERSATION_CREATED",
            userId,
            CancellationToken.None);

        return _mapper.ToUserSummary(conversation);
    }

    private async Task<SupportMessageHistoryDto> BuildMessageHistoryAsync(
        SupportConversation conversation,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken)
    {
        DecodeSequenceCursor(query.Cursor, out var beforeSequence);
        var messages = await _supportRepository.GetMessagesAsync(
            conversation.Id,
            beforeSequence,
            query.PageSize + 1,
            cancellationToken);

        var hasMore = messages.Count > query.PageSize;
        var selected = messages.Take(query.PageSize).Reverse().ToList();
        var nextCursor = hasMore && selected.Count > 0
            ? SupportCursorCodec.EncodeSequence(selected[0].SequenceNumber)
            : null;

        return new SupportMessageHistoryDto
        {
            Conversation = _mapper.ToUserSummary(conversation),
            Messages = new CursorPageDto<SupportMessageDto>
            {
                Items = selected.Select(MapUserMessage).ToList(),
                HasMore = hasMore,
                NextCursor = nextCursor
            }
        };
    }

    private async Task<SendSupportMessageResponseDto> SendUserMessageAsync(
        Guid conversationId,
        SendSupportMessageRequestDto request,
        Action<SupportConversation> ensureOwner,
        int? senderUserId,
        SupportAuditActorType actorType,
        CancellationToken cancellationToken)
    {
        var content = SupportDomain.NormalizeMessageContent(request.Content);
        var clientMessageId = request.ClientMessageId.Trim();

        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                ensureOwner(conversation);

                if (conversation.Status == SupportConversationStatus.CLOSED)
                {
                    throw new InvalidOperationException(
                        "Closed support conversations are archived. Start a new conversation to contact support.");
                }

                var existingMessage = await _supportRepository.GetMessageByClientIdAsync(
                    conversation.Id,
                    SupportParticipantType.User,
                    clientMessageId,
                    operationCancellationToken);

                if (existingMessage is not null)
                {
                    if (!string.Equals(existingMessage.Content, content, StringComparison.Ordinal))
                    {
                        throw new InvalidOperationException(
                            "ClientMessageId has already been used with different message content.");
                    }

                    return new MessageMutationResult(
                        BuildSendResponse(existingMessage, conversation, true),
                        false,
                        false);
                }

                var now = DateTime.UtcNow;
                var reopened = conversation.Status == SupportConversationStatus.RESOLVED;
                if (reopened)
                {
                    var previousStatus = conversation.Status;
                    conversation.Status = SupportConversationStatus.AI_ACTIVE;
                    conversation.ResolvedAt = null;
                    conversation.AssignedAdminUserId = null;
                    await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                        conversation.Id,
                        SupportAuditEventType.Reopened,
                        actorType,
                        senderUserId,
                        previousStatus,
                        conversation.Status,
                        now), operationCancellationToken);
                }

                var message = SupportDomain.CreateMessage(
                    conversation,
                    SupportParticipantType.User,
                    senderUserId,
                    clientMessageId,
                    content,
                    now);

                await _supportRepository.AddMessageAsync(message, operationCancellationToken);
                SupportDomain.ApplyMessageMetadata(conversation, message);
                conversation.ReadState.UserLastReadSequence = message.SequenceNumber;
                conversation.ReadState.UserUnreadCount = 0;
                conversation.ReadState.UserReadAt = now;
                conversation.ReadState.AdminUnreadCount++;

                return new MessageMutationResult(
                    BuildSendResponse(message, conversation, false),
                    true,
                    reopened);
            },
            cancellationToken);

        if (result.Reopened)
        {
            await _realtimeNotifier.PublishAsync(
                conversationId,
                null,
                null,
                "CONVERSATION_REOPENED",
                senderUserId,
                CancellationToken.None);
        }

        if (result.Created)
        {
            await _realtimeNotifier.PublishAsync(
                conversationId,
                result.Response.Message.Id,
                result.Response.Message.SequenceNumber,
                "MESSAGE_CREATED",
                senderUserId,
                CancellationToken.None);
        }

        result.Response.Automation = await _aiOrchestrator.ProcessUserMessageAsync(
            conversationId,
            result.Response.Message.Id,
            senderUserId,
            CancellationToken.None);

        var updatedConversation = await GetConversationAsync(conversationId, CancellationToken.None);
        result.Response.Conversation = _mapper.ToUserSummary(updatedConversation);

        return result.Response;
    }

    private async Task<SupportConversationSummaryDto> RequestAdminAsync(
        Guid conversationId,
        Action<SupportConversation> ensureOwner,
        int? actorUserId,
        SupportAuditActorType actorType,
        CancellationToken cancellationToken)
    {
        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                ensureOwner(conversation);

                if (conversation.Status == SupportConversationStatus.CLOSED)
                {
                    throw new InvalidOperationException(
                        "Closed support conversations are archived. Start a new conversation to contact support.");
                }

                if (conversation.Status == SupportConversationStatus.RESOLVED)
                {
                    throw new InvalidOperationException(
                        "Send a new message to reopen this conversation before requesting an administrator.");
                }

                if (conversation.Status is SupportConversationStatus.WAITING_FOR_ADMIN
                    or SupportConversationStatus.ADMIN_ACTIVE)
                {
                    return new ConversationMutationResult(
                        _mapper.ToUserSummary(conversation),
                        false);
                }

                var now = DateTime.UtcNow;
                var previousStatus = conversation.Status;
                conversation.Status = SupportConversationStatus.WAITING_FOR_ADMIN;
                conversation.AssignedAdminUserId = null;
                conversation.UpdatedAt = now;
                await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                    conversation.Id,
                    SupportAuditEventType.AdminHandoffRequested,
                    actorType,
                    actorUserId,
                    previousStatus,
                    conversation.Status,
                    now), operationCancellationToken);

                return new ConversationMutationResult(
                    _mapper.ToUserSummary(conversation),
                    true);
            },
            cancellationToken);

        if (result.Changed)
        {
            await _realtimeNotifier.PublishAsync(
                conversationId,
                null,
                null,
                "ADMIN_HANDOFF_REQUESTED",
                actorUserId,
                CancellationToken.None);
        }

        return result.Conversation;
    }

    private async Task<SupportUnreadCountDto> MarkReadAsync(
        Guid conversationId,
        Action<SupportConversation> ensureOwner,
        int? ownerUserId,
        Func<Task<int>> getTotalUnread,
        CancellationToken cancellationToken)
    {
        await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            (conversation, _) =>
            {
                ensureOwner(conversation);
                conversation.ReadState.UserLastReadSequence = conversation.LastMessageSequence;
                conversation.ReadState.UserUnreadCount = 0;
                conversation.ReadState.UserReadAt = DateTime.UtcNow;
                return Task.FromResult(true);
            },
            cancellationToken);

        var totalUnread = await getTotalUnread();
        await _realtimeNotifier.PublishAsync(
            conversationId,
            null,
            null,
            "UNREAD_STATE_CHANGED",
            ownerUserId,
            CancellationToken.None);

        return new SupportUnreadCountDto
        {
            UnreadMessages = totalUnread
        };
    }

    private CursorPageDto<SupportConversationSummaryDto> BuildConversationPage(
        IReadOnlyList<SupportConversation> conversations,
        int pageSize)
    {
        var hasMore = conversations.Count > pageSize;
        var selected = conversations.Take(pageSize).ToList();
        var last = selected.LastOrDefault();

        return new CursorPageDto<SupportConversationSummaryDto>
        {
            Items = selected.Select(_mapper.ToUserSummary).ToList(),
            HasMore = hasMore,
            NextCursor = hasMore && last is not null
                ? SupportCursorCodec.EncodeConversation(last.UpdatedAt, last.Id)
                : null
        };
    }

    private SendSupportMessageResponseDto BuildSendResponse(
        SupportMessage message,
        SupportConversation conversation,
        bool isDuplicate)
    {
        return new SendSupportMessageResponseDto
        {
            Message = MapUserMessage(message),
            Conversation = _mapper.ToUserSummary(conversation),
            IsDuplicate = isDuplicate
        };
    }

    private async Task<SupportConversation> GetConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        return await _supportRepository.GetConversationAsync(conversationId, cancellationToken)
            ?? throw new KeyNotFoundException("Support conversation not found.");
    }

    private async Task<AnonymousSupportSession> GetActiveAnonymousSessionAsync(
        string sessionToken,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(sessionToken) || sessionToken.Length > 256)
        {
            throw new UnauthorizedAccessException("Anonymous support session is invalid or expired.");
        }

        var tokenHash = AnonymousSupportToken.Hash(sessionToken.Trim());
        var session = await _supportRepository.GetAnonymousSessionByTokenHashAsync(tokenHash, cancellationToken);

        if (session is null
            || session.ExpiresAt <= DateTime.UtcNow
            || session.ClaimedByUserId.HasValue)
        {
            throw new UnauthorizedAccessException("Anonymous support session is invalid or expired.");
        }

        return session;
    }

    private static void EnsureUserOwns(SupportConversation conversation, int userId)
    {
        if (conversation.UserId != userId || conversation.AnonymousSessionId.HasValue)
        {
            throw new KeyNotFoundException("Support conversation not found.");
        }
    }

    private static void EnsureAnonymousOwns(SupportConversation conversation, Guid anonymousSessionId)
    {
        if (conversation.AnonymousSessionId != anonymousSessionId || conversation.UserId.HasValue)
        {
            throw new KeyNotFoundException("Support conversation not found.");
        }
    }

    private static void TouchSession(AnonymousSupportSession session)
    {
        session.LastSeenAt = DateTime.UtcNow;
    }

    private SupportMessageDto MapUserMessage(SupportMessage message)
    {
        var dto = _mapper.Map<SupportMessageDto>(message);
        if (message.SenderType == SupportParticipantType.User)
        {
            dto.SenderDisplayName = "You";
        }

        return dto;
    }

    private static void DecodeConversationCursor(
        string? cursor,
        out DateTime? updatedAt,
        out Guid? id)
    {
        if (!SupportCursorCodec.TryDecodeConversation(cursor, out updatedAt, out id))
        {
            throw InvalidCursor();
        }
    }

    private static void DecodeSequenceCursor(string? cursor, out long? sequenceNumber)
    {
        if (!SupportCursorCodec.TryDecodeSequence(cursor, out sequenceNumber))
        {
            throw InvalidCursor();
        }
    }

    private static ValidationException InvalidCursor()
    {
        return new ValidationException(new[]
        {
            new ValidationFailure("Cursor", "Cursor is invalid.")
        });
    }

    private sealed record MessageMutationResult(
        SendSupportMessageResponseDto Response,
        bool Created,
        bool Reopened);

    private sealed record ConversationMutationResult(
        SupportConversationSummaryDto Conversation,
        bool Changed);
}
