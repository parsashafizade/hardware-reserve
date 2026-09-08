namespace FinalMvcApp.DTOs.Support;

public class AdminSendSupportMessageResponseDto
{
    public SupportMessageDto Message { get; set; } = new();

    public AdminSupportConversationDto Conversation { get; set; } = new();

    public bool IsDuplicate { get; set; }
}
