namespace FinalMvcApp.Services.Interfaces;

public interface ISupportRealtimeNotifier
{
    Task PublishAsync(
        Guid conversationId,
        Guid? messageId,
        long? sequenceNumber,
        string eventType,
        int? ownerUserId,
        CancellationToken cancellationToken = default);
}
