using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.DTOs.Common;
using FinalMvcApp.Options;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FinalMvcApp.Controllers;

[ApiController]
[Route("auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.Authentication)]
    [HttpGet("captcha")]
    public ActionResult<CaptchaChallengeResponseDto> GetCaptcha()
    {
        var response = _authService.GetCaptcha();
        return Ok(response);
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.Authentication)]
    [HttpPost("register")]
    public async Task<ActionResult<RegisterResponseDto>> Register(
        RegisterRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _authService.RegisterAsync(
            request,
            cancellationToken);

        return Ok(response);
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeVerify)]
    [HttpPost("verify-email")]
    public async Task<ActionResult<AuthResponseDto>> VerifyEmail(
        VerifyEmailRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _authService.VerifyEmailAsync(
            request,
            GetIpAddress(),
            cancellationToken);

        return Ok(response);
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeSend)]
    [HttpPost("resend-verification-code")]
    public async Task<ActionResult<MessageResponseDto>> ResendVerificationCode(
        ResendVerificationCodeRequestDto request,
        CancellationToken cancellationToken)
    {
        await _authService.ResendVerificationCodeAsync(
            request,
            cancellationToken);

        return Ok(new MessageResponseDto
        {
            Message = "If verification is required, a new code has been sent."
        });
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.Authentication)]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login(
        LoginRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _authService.LoginAsync(
            request,
            GetIpAddress(),
            cancellationToken);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponseDto>> Refresh(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _authService.RefreshAsync(
            request,
            GetIpAddress(),
            cancellationToken);

        return Ok(response);
    }

    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<ActionResult<MessageResponseDto>> Logout(
        LogoutRequestDto request,
        CancellationToken cancellationToken)
    {
        await _authService.LogoutAsync(
            request,
            cancellationToken);

        return Ok(new MessageResponseDto
        {
            Message = "Logged out successfully."
        });
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeSend)]
    [HttpPost("forgot-password")]
    public async Task<ActionResult<MessageResponseDto>> ForgotPassword(
        ForgotPasswordRequestDto request,
        CancellationToken cancellationToken)
    {
        await _authService.ForgotPasswordAsync(
            request,
            cancellationToken);

        return Ok(new MessageResponseDto
        {
            Message = "If the email exists, a password reset code has been sent."
        });
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeVerify)]
    [HttpPost("verify-password-reset-code")]
    public async Task<ActionResult<VerifyPasswordResetCodeResponseDto>>
        VerifyPasswordResetCode(
            VerifyPasswordResetCodeRequestDto request,
            CancellationToken cancellationToken)
    {
        var response =
            await _authService.VerifyPasswordResetCodeAsync(
                request,
                cancellationToken);

        return Ok(response);
    }

    [AllowAnonymous]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeVerify)]
    [HttpPost("reset-password")]
    public async Task<ActionResult<AuthResponseDto>> ResetPassword(
        ResetPasswordRequestDto request,
        CancellationToken cancellationToken)
    {
        var response =
            await _authService.ResetPasswordAsync(
                request,
                GetIpAddress(),
                cancellationToken);

        return Ok(response);
    }

    private string GetIpAddress()
    {
        return HttpContext.Connection.RemoteIpAddress?.ToString()
            ?? "unknown";
    }
}
