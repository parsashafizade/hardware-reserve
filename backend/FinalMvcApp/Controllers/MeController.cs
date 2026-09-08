using FinalMvcApp.DTOs.Profile;
using FinalMvcApp.Extensions;
using FinalMvcApp.Options;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize]
[Route("me")]
public class MeController : ControllerBase
{
    private readonly IProfileService _profileService;
    private readonly IEmailChangeService _emailChangeService;

    public MeController(
        IProfileService profileService,
        IEmailChangeService emailChangeService)
    {
        _profileService = profileService;
        _emailChangeService = emailChangeService;
    }

    [HttpGet]
    public async Task<ActionResult<ProfileResponseDto>> Get(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _profileService.GetAsync(userId, cancellationToken);
        return Ok(response);
    }

    [HttpPut]
    public async Task<ActionResult<ProfileResponseDto>> Update(UpdateProfileRequestDto request, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _profileService.UpdateAsync(userId, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("profile-image")]
    [Consumes("multipart/form-data")]
    // Leave room for multipart boundaries and headers; ProfileService still
    // enforces the actual file limit at exactly 2 MiB.
    [RequestSizeLimit((2 * 1024 * 1024) + (64 * 1024))]
    public async Task<ActionResult<ProfileResponseDto>> UploadProfileImage(
        [FromForm] UploadProfileImageRequest request,
        CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _profileService.UploadProfileImageAsync(userId, request.File, cancellationToken);
        return Ok(response);
    }

    [HttpGet("email-change")]
    public async Task<ActionResult<EmailChangeStatusDto>> GetEmailChange(
        CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.GetStatusAsync(
            User.GetUserId(),
            cancellationToken);

        return response is null
            ? NoContent()
            : Ok(response);
    }

    [HttpPost("email-change")]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeSend)]
    public async Task<ActionResult<EmailChangeStatusDto>> StartEmailChange(
        StartEmailChangeRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.StartAsync(
            User.GetUserId(),
            request,
            cancellationToken);

        return Ok(response);
    }

    [HttpPost("email-change/verify-current")]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeVerify)]
    public async Task<ActionResult<EmailChangeVerificationResponseDto>>
        VerifyCurrentEmailChange(
            VerifyEmailChangeCodeRequestDto request,
            CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.VerifyCurrentAsync(
            User.GetUserId(),
            request,
            GetIpAddress(),
            cancellationToken);

        return Ok(response);
    }

    [HttpPost("email-change/verify-new")]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeVerify)]
    public async Task<ActionResult<EmailChangeVerificationResponseDto>>
        VerifyNewEmailChange(
            VerifyEmailChangeCodeRequestDto request,
            CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.VerifyNewAsync(
            User.GetUserId(),
            request,
            GetIpAddress(),
            cancellationToken);

        return Ok(response);
    }

    [HttpPost("email-change/resend-current")]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeSend)]
    public async Task<ActionResult<EmailChangeStatusDto>>
        ResendCurrentEmailChange(CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.ResendCurrentAsync(
            User.GetUserId(),
            cancellationToken);

        return Ok(response);
    }

    [HttpPost("email-change/resend-new")]
    [EnableRateLimiting(AuthRateLimitPolicies.CodeSend)]
    public async Task<ActionResult<EmailChangeStatusDto>>
        ResendNewEmailChange(CancellationToken cancellationToken)
    {
        var response = await _emailChangeService.ResendNewAsync(
            User.GetUserId(),
            cancellationToken);

        return Ok(response);
    }

    [HttpDelete("email-change")]
    public async Task<IActionResult> CancelEmailChange(
        CancellationToken cancellationToken)
    {
        await _emailChangeService.CancelAsync(
            User.GetUserId(),
            cancellationToken);

        return NoContent();
    }

    private string GetIpAddress()
    {
        return HttpContext.Connection.RemoteIpAddress?.ToString()
            ?? "unknown";
    }
}
