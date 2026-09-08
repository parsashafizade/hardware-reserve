namespace FinalMvcApp.DTOs.Support;

public class SupportMessageDto
{
    public Guid Id { get; set; }

    public Guid ConversationId { get; set; }

    public long SequenceNumber { get; set; }

    public string SenderType { get; set; } = string.Empty;

    public string SenderDisplayName { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    public string ContentFormat { get; set; } = "PLAIN_TEXT";

    public DateTime CreatedAt { get; set; }
}
