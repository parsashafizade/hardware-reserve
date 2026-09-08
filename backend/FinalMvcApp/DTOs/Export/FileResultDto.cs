namespace FinalMvcApp.DTOs.Export;

public class FileResultDto
{
    public byte[] Content { get; set; } = [];

    public string FileName { get; set; } = string.Empty;

    public string ContentType { get; set; } = string.Empty;
}
