namespace FinalMvcApp.DTOs.Support;

public class SupportLastMessageDto
{
    public long SequenceNumber { get; set; }

    public string SenderType { get; set; } = string.Empty;

    public string Preview { get; set; } = string.Empty;

    public DateTime SentAt { get; set; }
}
