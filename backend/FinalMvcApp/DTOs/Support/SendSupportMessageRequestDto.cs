namespace FinalMvcApp.DTOs.Support;

public class SendSupportMessageRequestDto
{
    public string ClientMessageId { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;
}
