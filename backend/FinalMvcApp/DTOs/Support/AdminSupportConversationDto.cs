namespace FinalMvcApp.DTOs.Support;

public class AdminSupportConversationDto : SupportConversationSummaryDto
{
    public AdminSupportOwnerDto Owner { get; set; } = new();

    public bool IsAssignedToCurrentAdmin { get; set; }

    public bool IsAssigned { get; set; }

    public string? AiHandoffSummary { get; set; }

    public string? AiHandoffReason { get; set; }

    public DateTime? AiHandoffGeneratedAt { get; set; }
}
