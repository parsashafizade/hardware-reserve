using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Errors;
using Microsoft.Extensions.Caching.Memory;
using System.Reflection;

namespace FinalMvcApp.Tests;

public class MathCaptchaServiceTests
{
    [Fact]
    public void ValidateAndConsume_WhenUsedTwice_RejectsSecondAttempt()
    {
        using var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var captchaService = new MathCaptchaService(memoryCache);

        var challenge = captchaService.CreateChallenge();
        var expectedAnswer = challenge.A + challenge.B;

        captchaService.ValidateAndConsume(challenge.CaptchaId, expectedAnswer);

        var secondAttempt = () => captchaService.ValidateAndConsume(challenge.CaptchaId, expectedAnswer);

        var exception = Assert.Throws<ApiException>(secondAttempt);
        Assert.Equal(ApiErrorCodes.CaptchaInvalidOrExpired, exception.Code);
    }

    [Fact]
    public void ValidateAndConsume_WhenExpired_ReturnsStableErrorCode()
    {
        using var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var captchaService = new MathCaptchaService(memoryCache);

        var challenge = captchaService.CreateChallenge();
        var expectedAnswer = challenge.A + challenge.B;

        var found = memoryCache.TryGetValue(challenge.CaptchaId, out object? cachedValue);
        Assert.True(found);
        Assert.NotNull(cachedValue);

        var expiresAtProperty = cachedValue!.GetType().GetProperty(
            "ExpiresAtUtc",
            BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

        Assert.NotNull(expiresAtProperty);
        expiresAtProperty!.SetValue(cachedValue, DateTime.UtcNow.AddMinutes(-1));

        var action = () => captchaService.ValidateAndConsume(challenge.CaptchaId, expectedAnswer);

        var exception = Assert.Throws<ApiException>(action);
        Assert.Equal(ApiErrorCodes.CaptchaInvalidOrExpired, exception.Code);
    }
}
