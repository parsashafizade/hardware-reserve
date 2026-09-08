using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Hubs;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace FinalMvcApp.Services.Implementations;

public class SupportRealtimeNotifier : ISupportRealtimeNotifier
{
    public const string ClientEventName = "SupportEvent";
    private readonly IHubContext<SupportHub> _hubContext;
    private readonly ISupportRepository _supportRepository;
    private readonly ILogger<SupportRealtimeNotifier> _logger;

    public SupportRealtimeNotifier(
        IHubContext<SupportHub> hubContext,
        ISupportRepository supportRepository,
        ILogger<SupportRealtimeNotifier> logger)
    {
        _hubContext = hubContext;
        _supportRepository = supportRepository;
        _logger = logger;
    }

    public async Task PublishAsync(
        Guid conversationId,
        Guid? messageId,
        long? sequenceNumber,
        string eventType,
        int? ownerUserId,
        CancellationToken cancellationToken = default)
    {
        var notification = new SupportRealtimeNotificationDto
        {
            NotificationId = Guid.NewGuid(),
            ConversationId = conversationId,
            MessageId = messageId,
            SequenceNumber = sequenceNumber,
            EventType = eventType,
            OccurredAt = DateTime.UtcNow
        };

        var groups = new List<string>
        {
            SupportHubGroups.Admins
        };

        if (ownerUserId.HasValue)
        {
            groups.Add(SupportHubGroups.User(ownerUserId.Value));
        }

        // Conversation subscribers are already represented by the owner or admin audience.
        // Including the conversation group here sends the same event twice to an open thread.

        try
        {
            await _hubContext.Clients
                .Groups(groups)
                .SendAsync(ClientEventName, notification, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Support realtime publication failed for conversation {ConversationId} and event {EventType}",
                conversationId,
                eventType);

            await PersistFailureAsync(conversationId, eventType, exception);
        }
    }

    private async Task PersistFailureAsync(Guid conversationId, string eventType, Exception exception)
    {
        try
        {
            var details = $"event={eventType};failureType={exception.GetType().Name}";
            if (details.Length > 1000)
            {
                details = details[..1000];
            }

            await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                conversationId,
                SupportAuditEventType.RealtimeDeliveryFailed,
                SupportAuditActorType.System,
                null,
                null,
                null,
                DateTime.UtcNow,
                details));
            await _supportRepository.SaveChangesAsync(CancellationToken.None);
        }
        catch (Exception auditException)
        {
            _logger.LogError(
                auditException,
                "Could not persist support realtime failure for conversation {ConversationId}",
                conversationId);
        }
    }
}
