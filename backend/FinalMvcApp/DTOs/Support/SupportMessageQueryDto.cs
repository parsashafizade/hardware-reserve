namespace FinalMvcApp.DTOs.Support;

public class SupportMessageQueryDto
{
    public string? Cursor { get; set; }

    public int PageSize { get; set; } = 50;
}
