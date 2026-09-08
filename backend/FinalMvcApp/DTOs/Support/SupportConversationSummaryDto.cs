namespace FinalMvcApp.DTOs.Support;

public class SupportConversationSummaryDto
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Category { get; set; }

    public string Status { get; set; } = string.Empty;

    public bool IsAnonymous { get; set; }

    public int UnreadCount { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public DateTime? ResolvedAt { get; set; }

    public DateTime? ClosedAt { get; set; }

    public SupportLastMessageDto? LastMessage { get; set; }
}
