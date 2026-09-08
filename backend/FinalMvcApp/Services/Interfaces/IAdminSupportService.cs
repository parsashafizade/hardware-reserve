using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Support;

namespace FinalMvcApp.Services.Interfaces;

public interface IAdminSupportService
{
    Task<CursorPageDto<AdminSupportConversationDto>> GetConversationsAsync(
        int adminUserId,
        AdminSupportConversationQueryDto query,
        CancellationToken cancellationToken = default);

    Task<AdminSupportMessageHistoryDto> GetMessagesAsync(
        int adminUserId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default);

    Task<CursorPageDto<SupportConversationEventDto>> GetEventsAsync(
        int adminUserId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default);

    Task<AdminSupportConversationDto> ClaimAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<AdminSendSupportMessageResponseDto> SendMessageAsync(
        int adminUserId,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> MarkReadAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<AdminSupportConversationDto> ResolveAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<AdminSupportConversationDto> CloseAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<AdminSupportConversationDto> UpdateTitleAsync(
        int adminUserId,
        Guid conversationId,
        UpdateSupportConversationTitleRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> GetUnreadCountAsync(
        int adminUserId,
        CancellationToken cancellationToken = default);

    Task<SupportSuggestedReplyDto> GenerateSuggestedReplyAsync(
        int adminUserId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportQuickReplyDto>> GetQuickRepliesAsync(
        int adminUserId,
        bool includeInactive,
        CancellationToken cancellationToken = default);

    Task<SupportQuickReplyDto> CreateQuickReplyAsync(
        int adminUserId,
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SupportQuickReplyDto> UpdateQuickReplyAsync(
        int adminUserId,
        Guid quickReplyId,
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken = default);

    Task DeactivateQuickReplyAsync(
        int adminUserId,
        Guid quickReplyId,
        CancellationToken cancellationToken = default);
}
