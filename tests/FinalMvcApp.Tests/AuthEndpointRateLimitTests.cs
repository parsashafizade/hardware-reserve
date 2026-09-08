using FinalMvcApp.Controllers;
using FinalMvcApp.Options;
using Microsoft.AspNetCore.RateLimiting;
using System.Reflection;

namespace FinalMvcApp.Tests;

public class AuthEndpointRateLimitTests
{
    [Theory]
    [InlineData(nameof(AuthController.GetCaptcha), AuthRateLimitPolicies.Authentication)]
    [InlineData(nameof(AuthController.Register), AuthRateLimitPolicies.Authentication)]
    [InlineData(nameof(AuthController.Login), AuthRateLimitPolicies.Authentication)]
    [InlineData(nameof(AuthController.ResendVerificationCode), AuthRateLimitPolicies.CodeSend)]
    [InlineData(nameof(AuthController.ForgotPassword), AuthRateLimitPolicies.CodeSend)]
    [InlineData(nameof(AuthController.VerifyEmail), AuthRateLimitPolicies.CodeVerify)]
    [InlineData(nameof(AuthController.VerifyPasswordResetCode), AuthRateLimitPolicies.CodeVerify)]
    [InlineData(nameof(AuthController.ResetPassword), AuthRateLimitPolicies.CodeVerify)]
    public void SensitiveAuthEndpoint_UsesExpectedRateLimitPolicy(
        string actionName,
        string expectedPolicy)
    {
        var action = typeof(AuthController).GetMethod(actionName)
            ?? throw new InvalidOperationException(
                $"Auth action '{actionName}' was not found.");
        var attribute = action.GetCustomAttribute<EnableRateLimitingAttribute>();

        Assert.NotNull(attribute);
        Assert.Equal(expectedPolicy, attribute.PolicyName);
    }

    [Theory]
    [InlineData(nameof(MeController.StartEmailChange), AuthRateLimitPolicies.CodeSend)]
    [InlineData(nameof(MeController.ResendCurrentEmailChange), AuthRateLimitPolicies.CodeSend)]
    [InlineData(nameof(MeController.ResendNewEmailChange), AuthRateLimitPolicies.CodeSend)]
    [InlineData(nameof(MeController.VerifyCurrentEmailChange), AuthRateLimitPolicies.CodeVerify)]
    [InlineData(nameof(MeController.VerifyNewEmailChange), AuthRateLimitPolicies.CodeVerify)]
    public void EmailChangeEndpoint_UsesExpectedRateLimitPolicy(
        string actionName,
        string expectedPolicy)
    {
        var action = typeof(MeController).GetMethod(actionName)
            ?? throw new InvalidOperationException(
                $"Profile action '{actionName}' was not found.");
        var attribute = action.GetCustomAttribute<EnableRateLimitingAttribute>();

        Assert.NotNull(attribute);
        Assert.Equal(expectedPolicy, attribute.PolicyName);
    }
}
