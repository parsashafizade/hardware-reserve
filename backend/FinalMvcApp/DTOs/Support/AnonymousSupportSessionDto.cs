namespace FinalMvcApp.DTOs.Support;

public class AnonymousSupportSessionDto
{
    public string SessionToken { get; set; } = string.Empty;

    public DateTime ExpiresAt { get; set; }
}
