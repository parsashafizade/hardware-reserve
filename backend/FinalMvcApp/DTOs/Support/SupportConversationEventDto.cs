namespace FinalMvcApp.DTOs.Support;

public class SupportConversationEventDto
{
    public Guid Id { get; set; }

    public string EventType { get; set; } = string.Empty;

    public string ActorType { get; set; } = string.Empty;

    public string? PreviousStatus { get; set; }

    public string? NewStatus { get; set; }

    public string? Details { get; set; }

    public DateTime OccurredAt { get; set; }
}
