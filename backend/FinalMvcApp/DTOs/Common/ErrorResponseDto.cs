namespace FinalMvcApp.DTOs.Common;

public class ErrorResponseDto
{
    public string TraceId { get; set; } = string.Empty;

    public string? Code { get; set; }

    public string Message { get; set; } = string.Empty;

    public Dictionary<string, string[]>? Errors { get; set; }
}