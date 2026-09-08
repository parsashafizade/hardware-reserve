namespace FinalMvcApp.DTOs.Support;

public class UpsertSupportQuickReplyRequestDto
{
    public string Title { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    public string? Category { get; set; }

    public bool IsActive { get; set; } = true;

    public int SortOrder { get; set; }
}
