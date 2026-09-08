using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Support;

namespace FinalMvcApp.Services.Interfaces;

public interface ISupportService
{
    Task<AnonymousSupportSessionDto> CreateAnonymousSessionAsync(CancellationToken cancellationToken = default);

    Task<SupportConversationSummaryDto> CreateForUserAsync(
        int userId,
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SupportConversationSummaryDto> CreateForAnonymousAsync(
        string sessionToken,
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken = default);

    Task<CursorPageDto<SupportConversationSummaryDto>> GetForUserAsync(
        int userId,
        SupportConversationQueryDto query,
        CancellationToken cancellationToken = default);

    Task<CursorPageDto<SupportConversationSummaryDto>> GetForAnonymousAsync(
        string sessionToken,
        SupportConversationQueryDto query,
        CancellationToken cancellationToken = default);

    Task<SupportMessageHistoryDto> GetMessagesForUserAsync(
        int userId,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default);

    Task<SupportMessageHistoryDto> GetMessagesForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        SupportMessageQueryDto query,
        CancellationToken cancellationToken = default);

    Task<SendSupportMessageResponseDto> SendForUserAsync(
        int userId,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SendSupportMessageResponseDto> SendForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken = default);

    Task<SupportConversationSummaryDto> RequestAdminForUserAsync(
        int userId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<SupportConversationSummaryDto> RequestAdminForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> MarkReadForUserAsync(
        int userId,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> MarkReadForAnonymousAsync(
        string sessionToken,
        Guid conversationId,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> GetUnreadCountForUserAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<SupportUnreadCountDto> GetUnreadCountForAnonymousAsync(
        string sessionToken,
        CancellationToken cancellationToken = default);

    Task<bool> CanSubscribeAsync(
        int userId,
        bool isAdmin,
        Guid conversationId,
        CancellationToken cancellationToken = default);
}
