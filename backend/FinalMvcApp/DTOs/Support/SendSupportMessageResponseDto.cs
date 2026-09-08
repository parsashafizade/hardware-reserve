namespace FinalMvcApp.DTOs.Support;

public class SendSupportMessageResponseDto
{
    public SupportMessageDto Message { get; set; } = new();

    public SupportConversationSummaryDto Conversation { get; set; } = new();

    public bool IsDuplicate { get; set; }

    public SupportAutomationResultDto Automation { get; set; } = new();
}
