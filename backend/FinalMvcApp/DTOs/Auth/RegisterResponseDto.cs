namespace FinalMvcApp.DTOs.Auth;

public class RegisterResponseDto
{
    public string Email { get; set; } = string.Empty;

    public bool RequiresEmailVerification { get; set; }

    public string Message { get; set; } = string.Empty;
}
