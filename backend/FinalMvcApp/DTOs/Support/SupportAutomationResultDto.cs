namespace FinalMvcApp.DTOs.Support;

public class SupportAutomationResultDto
{
    public string Status { get; set; } = "SKIPPED";

    public SupportMessageDto? AssistantMessage { get; set; }
}
