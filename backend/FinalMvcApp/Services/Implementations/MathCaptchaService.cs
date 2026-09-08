using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.Errors;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using System.Security.Cryptography;

namespace FinalMvcApp.Services.Implementations;

public class MathCaptchaService : ICaptchaService
{
    private static readonly TimeSpan CaptchaLifetime = TimeSpan.FromMinutes(2);
    private readonly IMemoryCache _memoryCache;

    public MathCaptchaService(IMemoryCache memoryCache)
    {
        _memoryCache = memoryCache;
    }

    public CaptchaChallengeResponseDto CreateChallenge()
    {
        var firstNumber = RandomNumberGenerator.GetInt32(0, 10);
        var secondNumber = RandomNumberGenerator.GetInt32(0, 10);
        var captchaId = Guid.NewGuid().ToString("N");

        var challenge = new CaptchaCacheModel
        {
            ExpectedAnswer = firstNumber + secondNumber,
            ExpiresAtUtc = DateTime.UtcNow.Add(CaptchaLifetime)
        };

        _memoryCache.Set(captchaId, challenge, challenge.ExpiresAtUtc);

        return new CaptchaChallengeResponseDto
        {
            CaptchaId = captchaId,
            A = firstNumber,
            B = secondNumber
        };
    }

    public void ValidateAndConsume(string captchaId, int captchaAnswer)
    {
        if (!_memoryCache.TryGetValue<CaptchaCacheModel>(captchaId, out var challenge) || challenge is null)
        {
            throw new ApiException(
                ApiErrorCodes.CaptchaInvalidOrExpired,
                "Captcha is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        if (challenge.ExpiresAtUtc <= DateTime.UtcNow)
        {
            _memoryCache.Remove(captchaId);
            throw new ApiException(
                ApiErrorCodes.CaptchaInvalidOrExpired,
                "Captcha is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        if (challenge.ExpectedAnswer != captchaAnswer)
        {
            throw new ApiException(
                ApiErrorCodes.CaptchaAnswerIncorrect,
                "Captcha answer is incorrect.",
                StatusCodes.Status400BadRequest);
        }

        _memoryCache.Remove(captchaId);
    }

    private class CaptchaCacheModel
    {
        public int ExpectedAnswer { get; set; }

        public DateTime ExpiresAtUtc { get; set; }
    }
}
