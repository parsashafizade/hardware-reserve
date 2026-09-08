namespace FinalMvcApp.DTOs.Notifications;

public class NotificationReadStateRealtimeDto
{
    public Guid EventId { get; set; }

    public Guid? NotificationId { get; set; }

    public int UnreadCount { get; set; }

    public DateTime OccurredAt { get; set; }
}
