namespace FinalMvcApp.DTOs.Support;

public class AdminSupportConversationQueryDto : SupportConversationQueryDto
{
    public string? Status { get; set; }

    public string? Category { get; set; }
}
