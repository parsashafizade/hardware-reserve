using FinalMvcApp.DTOs.Auth;

namespace FinalMvcApp.Services.Interfaces;

public interface ICaptchaService
{
    CaptchaChallengeResponseDto CreateChallenge();

    void ValidateAndConsume(string captchaId, int captchaAnswer);
}
