using FinalMvcApp.DTOs.Auth;

namespace FinalMvcApp.Services.Interfaces;

public interface IAuthService
{
    CaptchaChallengeResponseDto GetCaptcha();

    Task<RegisterResponseDto> RegisterAsync(
        RegisterRequestDto request,
        CancellationToken cancellationToken = default);

    Task<AuthResponseDto> VerifyEmailAsync(
        VerifyEmailRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default);

    Task ResendVerificationCodeAsync(
        ResendVerificationCodeRequestDto request,
        CancellationToken cancellationToken = default);

    Task<AuthResponseDto> LoginAsync(
        LoginRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default);

    Task<AuthResponseDto> RefreshAsync(
        RefreshTokenRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default);

    Task LogoutAsync(
        LogoutRequestDto request,
        CancellationToken cancellationToken = default);

    Task ForgotPasswordAsync(
        ForgotPasswordRequestDto request,
        CancellationToken cancellationToken = default);

    Task<VerifyPasswordResetCodeResponseDto> VerifyPasswordResetCodeAsync(
    VerifyPasswordResetCodeRequestDto request,
    CancellationToken cancellationToken = default);

    Task<AuthResponseDto> ResetPasswordAsync(
    ResetPasswordRequestDto request,
    string ipAddress,
    CancellationToken cancellationToken = default);

    Task<AuthResponseDto> IssueSessionAsync(
        int userId,
        string ipAddress,
        CancellationToken cancellationToken = default);
}
