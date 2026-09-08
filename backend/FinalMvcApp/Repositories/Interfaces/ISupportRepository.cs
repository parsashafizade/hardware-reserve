using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Repositories.Interfaces;

public interface ISupportRepository
{
    Task AddConversationAsync(SupportConversation conversation, CancellationToken cancellationToken = default);

    Task AddAnonymousSessionAsync(AnonymousSupportSession session, CancellationToken cancellationToken = default);

    Task<AnonymousSupportSession?> GetAnonymousSessionByTokenHashAsync(
        string tokenHash,
        CancellationToken cancellationToken = default);

    Task<SupportConversation?> GetConversationAsync(Guid conversationId, CancellationToken cancellationToken = default);

    Task<bool> UserOwnsConversationAsync(int userId, Guid conversationId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportConversation>> GetUserConversationsAsync(
        int userId,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportConversation>> GetAnonymousConversationsAsync(
        Guid anonymousSessionId,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportConversation>> GetAdminConversationsAsync(
        SupportConversationStatus? status,
        string? category,
        DateTime? cursorUpdatedAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportMessage>> GetMessagesAsync(
        Guid conversationId,
        long? beforeSequence,
        int take,
        CancellationToken cancellationToken = default);

    Task<SupportMessage?> GetMessageByClientIdAsync(
        Guid conversationId,
        SupportParticipantType senderType,
        string clientMessageId,
        CancellationToken cancellationToken = default);

    Task AddMessageAsync(SupportMessage message, CancellationToken cancellationToken = default);

    Task<SupportMessage?> GetMessageByIdAsync(Guid messageId, CancellationToken cancellationToken = default);

    Task<SupportAiProcessing?> GetAiProcessingByUserMessageIdAsync(
        Guid userMessageId,
        bool asTracking,
        CancellationToken cancellationToken = default);

    Task AddAiProcessingAsync(
        SupportAiProcessing processing,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportConversationEvent>> GetEventsAsync(
        Guid conversationId,
        DateTime? cursorOccurredAt,
        Guid? cursorId,
        int take,
        CancellationToken cancellationToken = default);

    Task<int> GetUserUnreadCountAsync(int userId, CancellationToken cancellationToken = default);

    Task<int> GetAnonymousUnreadCountAsync(Guid anonymousSessionId, CancellationToken cancellationToken = default);

    Task<int> GetAdminUnreadCountAsync(CancellationToken cancellationToken = default);

    Task<TResult> ExecuteWithConversationLockAsync<TResult>(
        Guid conversationId,
        Func<SupportConversation, CancellationToken, Task<TResult>> operation,
        CancellationToken cancellationToken = default);

    Task AddEventAsync(SupportConversationEvent supportEvent, CancellationToken cancellationToken = default);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
