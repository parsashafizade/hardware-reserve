namespace FinalMvcApp.DTOs.Support;

public class SupportConversationQueryDto
{
    public string? Cursor { get; set; }

    public int PageSize { get; set; } = 20;
}
