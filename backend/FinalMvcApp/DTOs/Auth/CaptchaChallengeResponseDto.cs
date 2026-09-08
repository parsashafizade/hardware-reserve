namespace FinalMvcApp.DTOs.Auth;

public class CaptchaChallengeResponseDto
{
    public string CaptchaId { get; set; } = string.Empty;

    public int A { get; set; }

    public int B { get; set; }
}
