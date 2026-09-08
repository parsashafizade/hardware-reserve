namespace FinalMvcApp.DTOs.Support;

public class SupportRealtimeNotificationDto
{
    public Guid NotificationId { get; set; }

    public Guid ConversationId { get; set; }

    public Guid? MessageId { get; set; }

    public long? SequenceNumber { get; set; }

    public string EventType { get; set; } = string.Empty;

    public DateTime OccurredAt { get; set; }
}
