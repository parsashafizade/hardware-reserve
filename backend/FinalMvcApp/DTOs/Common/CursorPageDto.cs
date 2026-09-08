namespace FinalMvcApp.DTOs.Common;

public class CursorPageDto<T>
{
    public IReadOnlyList<T> Items { get; set; } = Array.Empty<T>();

    public string? NextCursor { get; set; }

    public bool HasMore { get; set; }
}
