namespace FinalMvcApp.DTOs.Notifications;

public class UserNotificationDto
{
    public Guid Id { get; set; }

    public string Type { get; set; } = string.Empty;

    public string Source { get; set; } = string.Empty;

    public string? ResourceLabel { get; set; }

    public string? Title { get; set; }

    public string? Message { get; set; }

    public int? ReservationId { get; set; }

    public Guid? SupportConversationId { get; set; }

    public DateTime? EventTime { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ReadAt { get; set; }
}
