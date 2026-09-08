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

public class AdminSupportService : IAdminSupportService
{
    private readonly ISupportRepository _supportRepository;
    private readonly ISupportQuickReplyRepository _quickReplyRepository;
    private readonly IUserRepository _userRepository;
    private readonly ISupportRealtimeNotifier _realtimeNotifier;
    private readonly ISupportAiOrchestrator _aiOrchestrator;
    private readonly IUserNotificationService _notificationService;
    private readonly IMapper _mapper;

    public AdminSupportService(
        ISupportRepository supportRepository,
        ISupportQuickReplyRepository quickReplyRepository,
        IUserRepository userRepository,
        ISupportRealtimeNotifier realtimeNotifier,
        ISupportAiOrchestrator aiOrchestrator,
        IUserNotificationService notificationService,
        IMapper mapper)
    {
        _supportRepository = supportRepository;
        _quickReplyRepository = quickReplyRepository;
        _userRepository = userRepository;
        _realtimeNotifier = realtimeNotifier;
        _aiOrchestrator = aiOrchestrator;
        _notificationService = notificationService;
        _mapper = mapper;
    }

    public async Task<CursorPageDto<AdminSupportConversationDto>> GetConversationsAsync(
        int adminUserId,
        AdminSupportConversationQueryDto query,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        DecodeConversationCursor(query.Cursor, out var cursorUpdatedAt, out var cursorId);

        SupportConversationStatus? status = null;
        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            if (!Enum.TryParse<SupportConversationStatus>(query.Status, true, out var parsedStatus))
            {
                throw ValidationError(nameof(query.Status), "Status is not a supported conversation status.");
            }

            status = parsedStatus;
        }

        var conversations = await _supportRepository.GetAdminConversationsAsync(
            status,
            SupportDomain.NormalizeOptional(query.Category),
            cursorUpdatedAt,
            cursorId,
            query.PageSize + 1,
            cancellationToken);

        var hasMore = conversations.Count > query.PageSize;
        var selected = conversations.Take(query.PageSize).ToList();
        var last = selected.LastOrDefault();

        return new CursorPageDto<AdminSupportConversationDto>
        {
            Items = selected.Select(conversation => _mapper.ToAdminSummary(conversation, adminUserId)).ToList(),
            HasMore = hasMore,
            NextCursor = hasMore && last is not null
                ? SupportCursorCodec.EncodeConversation(last.UpdatedAt, last.Id)
                : null
        };
    }

    public async Task<AdminSupportMessageHistoryDto> GetMessagesAsync(
        int adminUserId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var conversation = await GetConversationAsync(conversationId, cancellationToken);
        DecodeSequenceCursor(query.Cursor, out var beforeSequence);

        var messages = await _supportRepository.GetMessagesAsync(
            conversationId,
            beforeSequence,
            query.PageSize + 1,
            cancellationToken);

        var hasMore = messages.Count > query.PageSize;
        var selected = messages.Take(query.PageSize).Reverse().ToList();

        return new AdminSupportMessageHistoryDto
        {
            Conversation = _mapper.ToAdminSummary(conversation, adminUserId),
            Messages = new CursorPageDto<SupportMessageDto>
            {
                Items = _mapper.Map<IReadOnlyList<SupportMessageDto>>(selected),
                HasMore = hasMore,
                NextCursor = hasMore && selected.Count > 0
                    ? SupportCursorCodec.EncodeSequence(selected[0].SequenceNumber)
                    : null
            }
        };
    }

    public async Task<CursorPageDto<SupportConversationEventDto>> GetEventsAsync(
        int adminUserId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        _ = await GetConversationAsync(conversationId, cancellationToken);
        DecodeConversationCursor(query.Cursor, out var cursorOccurredAt, out var cursorId);

        var events = await _supportRepository.GetEventsAsync(
            conversationId,
            cursorOccurredAt,
            cursorId,
            query.PageSize + 1,
            cancellationToken);

        var hasMore = events.Count > query.PageSize;
        var selected = events.Take(query.PageSize).ToList();
        var last = selected.LastOrDefault();

        return new CursorPageDto<SupportConversationEventDto>
        {
            Items = _mapper.Map<IReadOnlyList<SupportConversationEventDto>>(selected),
            HasMore = hasMore,
            NextCursor = hasMore && last is not null
                ? SupportCursorCodec.EncodeConversation(last.OccurredAt, last.Id)
                : null
        };
    }

    public async Task<AdminSupportConversationDto> ClaimAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);

        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                if (conversation.Status == SupportConversationStatus.ADMIN_ACTIVE
                    && conversation.AssignedAdminUserId == adminUserId)
                {
                    return new ConversationMutationResult(
                        _mapper.ToAdminSummary(conversation, adminUserId),
                        false);
                }

                if (conversation.Status != SupportConversationStatus.WAITING_FOR_ADMIN)
                {
                    throw new InvalidOperationException("Only conversations waiting for an administrator can be claimed.");
                }

                var now = DateTime.UtcNow;
                var previousStatus = conversation.Status;
                conversation.Status = SupportConversationStatus.ADMIN_ACTIVE;
                conversation.AssignedAdminUserId = adminUserId;
                conversation.UpdatedAt = now;
                await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                    conversation.Id,
                    SupportAuditEventType.AdminClaimed,
                    SupportAuditActorType.Admin,
                    adminUserId,
                    previousStatus,
                    conversation.Status,
                    now), operationCancellationToken);

                return new ConversationMutationResult(
                    _mapper.ToAdminSummary(conversation, adminUserId),
                    true);
            },
            cancellationToken);

        if (result.Changed)
        {
            await PublishAsync(conversationId, "ADMIN_CLAIMED", result.Conversation, cancellationToken);
        }

        return result.Conversation;
    }

    public async Task<AdminSendSupportMessageResponseDto> SendMessageAsync(
        int adminUserId,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var content = SupportDomain.NormalizeMessageContent(request.Content);
        var clientMessageId = request.ClientMessageId.Trim();

        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                if (conversation.Status != SupportConversationStatus.ADMIN_ACTIVE
                    || conversation.AssignedAdminUserId != adminUserId)
                {
                    throw new InvalidOperationException(
                        "Claim this waiting conversation before sending an administrator reply.");
                }

                var existingMessage = await _supportRepository.GetMessageByClientIdAsync(
                    conversation.Id,
                    SupportParticipantType.Admin,
                    clientMessageId,
                    operationCancellationToken);

                if (existingMessage is not null)
                {
                    if (!string.Equals(existingMessage.Content, content, StringComparison.Ordinal))
                    {
                        throw new InvalidOperationException(
                            "ClientMessageId has already been used with different message content.");
                    }

                    return new AdminMessageMutationResult(
                        BuildSendResponse(existingMessage, conversation, adminUserId, true),
                        false);
                }

                var now = DateTime.UtcNow;
                var message = SupportDomain.CreateMessage(
                    conversation,
                    SupportParticipantType.Admin,
                    adminUserId,
                    clientMessageId,
                    content,
                    now);

                await _supportRepository.AddMessageAsync(message, operationCancellationToken);
                SupportDomain.ApplyMessageMetadata(conversation, message);
                conversation.ReadState.AdminLastReadSequence = message.SequenceNumber;
                conversation.ReadState.AdminUnreadCount = 0;
                conversation.ReadState.AdminReadAt = now;
                conversation.ReadState.UserUnreadCount++;

                return new AdminMessageMutationResult(
                    BuildSendResponse(message, conversation, adminUserId, false),
                    true);
            },
            cancellationToken);

        if (result.Created)
        {
            await _realtimeNotifier.PublishAsync(
                conversationId,
                result.Response.Message.Id,
                result.Response.Message.SequenceNumber,
                "MESSAGE_CREATED",
                result.Response.Conversation.Owner.UserId,
                CancellationToken.None);

            if (result.Response.Conversation.Owner.UserId is int ownerUserId)
            {
                await _notificationService.DispatchAsync(
                    new UserNotificationRequest(
                        ownerUserId,
                        UserNotificationType.SupportReply,
                        $"support-message:{result.Response.Message.Id:N}",
                        result.Response.Conversation.Title,
                        SupportConversationId: conversationId,
                        EventTime: result.Response.Message.CreatedAt),
                    CancellationToken.None);
            }
        }

        return result.Response;
    }

    public async Task<SupportUnreadCountDto> MarkReadAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);

        await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                conversation.ReadState.AdminLastReadSequence = conversation.LastMessageSequence;
                conversation.ReadState.AdminUnreadCount = 0;
                conversation.ReadState.AdminReadAt = DateTime.UtcNow;
                return Task.FromResult(true);
            },
            cancellationToken);

        await _realtimeNotifier.PublishAsync(
            conversationId,
            null,
            null,
            "UNREAD_STATE_CHANGED",
            null,
            CancellationToken.None);

        return new SupportUnreadCountDto
        {
            UnreadMessages = await _supportRepository.GetAdminUnreadCountAsync(cancellationToken)
        };
    }

    public async Task<AdminSupportConversationDto> ResolveAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await ChangeLifecycleAsync(
            adminUserId,
            conversationId,
            SupportConversationStatus.RESOLVED,
            SupportAuditEventType.Resolved,
            "CONVERSATION_RESOLVED",
            cancellationToken);
    }

    public async Task<AdminSupportConversationDto> CloseAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        return await ChangeLifecycleAsync(
            adminUserId,
            conversationId,
            SupportConversationStatus.CLOSED,
            SupportAuditEventType.Closed,
            "CONVERSATION_CLOSED",
            cancellationToken);
    }

    public async Task<AdminSupportConversationDto> UpdateTitleAsync(
        int adminUserId,
        Guid conversationId,
        UpdateSupportConversationTitleRequestDto request,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);

        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                var title = request.Title.Trim();
                if (conversation.Title == title)
                {
                    return new ConversationMutationResult(
                        _mapper.ToAdminSummary(conversation, adminUserId),
                        false);
                }

                var now = DateTime.UtcNow;
                conversation.Title = title;
                conversation.UpdatedAt = now;
                await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                    conversation.Id,
                    SupportAuditEventType.TitleChanged,
                    SupportAuditActorType.Admin,
                    adminUserId,
                    conversation.Status,
                    conversation.Status,
                    now), operationCancellationToken);

                return new ConversationMutationResult(
                    _mapper.ToAdminSummary(conversation, adminUserId),
                    true);
            },
            cancellationToken);

        if (result.Changed)
        {
            await PublishAsync(conversationId, "CONVERSATION_TITLE_CHANGED", result.Conversation, cancellationToken);
        }

        return result.Conversation;
    }

    public async Task<SupportUnreadCountDto> GetUnreadCountAsync(
        int adminUserId,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        return new SupportUnreadCountDto
        {
            UnreadMessages = await _supportRepository.GetAdminUnreadCountAsync(cancellationToken)
        };
    }

    public async Task<SupportSuggestedReplyDto> GenerateSuggestedReplyAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        _ = await GetConversationAsync(conversationId, cancellationToken);
        return await _aiOrchestrator.GenerateAdminSuggestedReplyAsync(
            conversationId,
            cancellationToken);
    }

    public async Task<IReadOnlyList<SupportQuickReplyDto>> GetQuickRepliesAsync(
        int adminUserId,
        bool includeInactive,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var quickReplies = await _quickReplyRepository.GetAllAsync(includeInactive, cancellationToken);
        return _mapper.Map<IReadOnlyList<SupportQuickReplyDto>>(quickReplies);
    }

    public async Task<SupportQuickReplyDto> CreateQuickReplyAsync(
        int adminUserId,
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var now = DateTime.UtcNow;
        var quickReply = new SupportQuickReply
        {
            Id = Guid.NewGuid(),
            Title = request.Title.Trim(),
            Content = SupportDomain.NormalizeMessageContent(request.Content),
            Category = SupportDomain.NormalizeOptional(request.Category),
            IsActive = request.IsActive,
            SortOrder = request.SortOrder,
            CreatedAt = now,
            UpdatedAt = now
        };

        await _quickReplyRepository.AddAsync(quickReply, cancellationToken);
        await _quickReplyRepository.SaveChangesAsync(cancellationToken);
        return _mapper.Map<SupportQuickReplyDto>(quickReply);
    }

    public async Task<SupportQuickReplyDto> UpdateQuickReplyAsync(
        int adminUserId,
        Guid quickReplyId,
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var quickReply = await _quickReplyRepository.GetByIdAsync(quickReplyId, cancellationToken)
            ?? throw new KeyNotFoundException("Support quick reply not found.");

        quickReply.Title = request.Title.Trim();
        quickReply.Content = SupportDomain.NormalizeMessageContent(request.Content);
        quickReply.Category = SupportDomain.NormalizeOptional(request.Category);
        quickReply.IsActive = request.IsActive;
        quickReply.SortOrder = request.SortOrder;
        quickReply.UpdatedAt = DateTime.UtcNow;

        _quickReplyRepository.Update(quickReply);
        await _quickReplyRepository.SaveChangesAsync(cancellationToken);
        return _mapper.Map<SupportQuickReplyDto>(quickReply);
    }

    public async Task DeactivateQuickReplyAsync(
        int adminUserId,
        Guid quickReplyId,
        CancellationToken cancellationToken = default)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);
        var quickReply = await _quickReplyRepository.GetByIdAsync(quickReplyId, cancellationToken)
            ?? throw new KeyNotFoundException("Support quick reply not found.");

        quickReply.IsActive = false;
        quickReply.UpdatedAt = DateTime.UtcNow;
        _quickReplyRepository.Update(quickReply);
        await _quickReplyRepository.SaveChangesAsync(cancellationToken);
    }

    private async Task<AdminSupportConversationDto> ChangeLifecycleAsync(
        int adminUserId,
        Guid conversationId,
        SupportConversationStatus targetStatus,
        SupportAuditEventType auditEventType,
        string realtimeEventType,
        CancellationToken cancellationToken)
    {
        await EnsureAdminAsync(adminUserId, cancellationToken);

        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                if (conversation.Status == SupportConversationStatus.CLOSED)
                {
                    if (targetStatus == SupportConversationStatus.CLOSED)
                    {
                        return new ConversationMutationResult(
                            _mapper.ToAdminSummary(conversation, adminUserId),
                            false);
                    }

                    throw new InvalidOperationException("Closed support conversations cannot change lifecycle state.");
                }

                if (conversation.AssignedAdminUserId != adminUserId)
                {
                    throw new InvalidOperationException(
                        "Only the administrator assigned to this conversation can change its lifecycle state.");
                }

                if (conversation.Status == targetStatus)
                {
                    return new ConversationMutationResult(
                        _mapper.ToAdminSummary(conversation, adminUserId),
                        false);
                }

                var isValidTransition = targetStatus switch
                {
                    SupportConversationStatus.RESOLVED =>
                        conversation.Status == SupportConversationStatus.ADMIN_ACTIVE,
                    SupportConversationStatus.CLOSED =>
                        conversation.Status is SupportConversationStatus.ADMIN_ACTIVE
                            or SupportConversationStatus.RESOLVED,
                    _ => false
                };

                if (!isValidTransition)
                {
                    throw new InvalidOperationException(
                        $"A support conversation in {conversation.Status} cannot transition to {targetStatus}.");
                }

                var now = DateTime.UtcNow;
                var previousStatus = conversation.Status;
                conversation.Status = targetStatus;
                conversation.UpdatedAt = now;

                if (targetStatus == SupportConversationStatus.RESOLVED)
                {
                    conversation.ResolvedAt = now;
                }
                else if (targetStatus == SupportConversationStatus.CLOSED)
                {
                    conversation.ClosedAt = now;
                }

                conversation.ReadState.AdminLastReadSequence = conversation.LastMessageSequence;
                conversation.ReadState.AdminUnreadCount = 0;
                conversation.ReadState.AdminReadAt = now;

                await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                    conversation.Id,
                    auditEventType,
                    SupportAuditActorType.Admin,
                    adminUserId,
                    previousStatus,
                    targetStatus,
                    now), operationCancellationToken);

                return new ConversationMutationResult(
                    _mapper.ToAdminSummary(conversation, adminUserId),
                    true);
            },
            cancellationToken);

        if (result.Changed)
        {
            await PublishAsync(conversationId, realtimeEventType, result.Conversation, cancellationToken);
        }

        return result.Conversation;
    }

    private AdminSendSupportMessageResponseDto BuildSendResponse(
        SupportMessage message,
        SupportConversation conversation,
        int adminUserId,
        bool isDuplicate)
    {
        return new AdminSendSupportMessageResponseDto
        {
            Message = _mapper.Map<SupportMessageDto>(message),
            Conversation = _mapper.ToAdminSummary(conversation, adminUserId),
            IsDuplicate = isDuplicate
        };
    }

    private async Task PublishAsync(
        Guid conversationId,
        string eventType,
        AdminSupportConversationDto conversation,
        CancellationToken cancellationToken)
    {
        _ = cancellationToken;
        await _realtimeNotifier.PublishAsync(
            conversationId,
            null,
            null,
            eventType,
            conversation.Owner.UserId,
            CancellationToken.None);
    }

    private async Task EnsureAdminAsync(int adminUserId, CancellationToken cancellationToken)
    {
        var user = await _userRepository.GetByIdAsync(adminUserId, cancellationToken);
        if (user?.Role != UserRole.Admin)
        {
            throw new UnauthorizedAccessException("Administrator access is required.");
        }
    }

    private async Task<SupportConversation> GetConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        return await _supportRepository.GetConversationAsync(conversationId, cancellationToken)
            ?? throw new KeyNotFoundException("Support conversation not found.");
    }

    private static void DecodeConversationCursor(
        string? cursor,
        out DateTime? updatedAt,
        out Guid? id)
    {
        if (!SupportCursorCodec.TryDecodeConversation(cursor, out updatedAt, out id))
        {
            throw ValidationError("Cursor", "Cursor is invalid.");
        }
    }

    private static void DecodeSequenceCursor(string? cursor, out long? sequenceNumber)
    {
        if (!SupportCursorCodec.TryDecodeSequence(cursor, out sequenceNumber))
        {
            throw ValidationError("Cursor", "Cursor is invalid.");
        }
    }

    private static ValidationException ValidationError(string propertyName, string message)
    {
        return new ValidationException(new[]
        {
            new ValidationFailure(propertyName, message)
        });
    }

    private sealed record ConversationMutationResult(
        AdminSupportConversationDto Conversation,
        bool Changed);

    private sealed record AdminMessageMutationResult(
        AdminSendSupportMessageResponseDto Response,
        bool Created);
}
