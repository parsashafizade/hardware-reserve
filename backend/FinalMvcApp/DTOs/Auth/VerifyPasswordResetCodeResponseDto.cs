namespace FinalMvcApp.DTOs.Auth;

public class VerifyPasswordResetCodeResponseDto
{
    public string ResetToken { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }
}