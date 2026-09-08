namespace FinalMvcApp.DTOs.Auth;

public class RegisterRequestDto
{
    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string CaptchaId { get; set; } = string.Empty;

    public int CaptchaAnswer { get; set; }
}
