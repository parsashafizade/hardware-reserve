using FinalMvcApp.Middleware;
using FinalMvcApp.Errors;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using System.Text.Json;

namespace FinalMvcApp.Tests;

public class GlobalExceptionHandlingMiddlewareTests
{
    [Fact]
    public async Task InvokeAsync_ApiException_ReturnsStableErrorCode()
    {
        var middleware = new GlobalExceptionHandlingMiddleware(
            _ => throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest),
            NullLogger<GlobalExceptionHandlingMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status400BadRequest, context.Response.StatusCode);
        context.Response.Body.Position = 0;
        using var payload = await JsonDocument.ParseAsync(context.Response.Body);
        Assert.Equal(
            ApiErrorCodes.EmailVerificationCodeInvalid,
            payload.RootElement.GetProperty("code").GetString());
    }

    [Fact]
    public async Task InvokeAsync_ReturnsCamelCaseSafeErrorContract()
    {
        var middleware = new GlobalExceptionHandlingMiddleware(
            _ => throw new InvalidOperationException("Safe business rule."),
            NullLogger<GlobalExceptionHandlingMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status400BadRequest, context.Response.StatusCode);
        context.Response.Body.Position = 0;
        using var payload = await JsonDocument.ParseAsync(context.Response.Body);
        Assert.Equal("Safe business rule.", payload.RootElement.GetProperty("message").GetString());
        Assert.True(payload.RootElement.TryGetProperty("traceId", out _));
        Assert.False(payload.RootElement.TryGetProperty("Message", out _));
    }

    [Fact]
    public async Task InvokeAsync_ReturnsPayloadTooLargeWithoutLeakingServerDetails()
    {
        var middleware = new GlobalExceptionHandlingMiddleware(
            _ => throw new BadHttpRequestException(
                "Internal parser details.",
                StatusCodes.Status413PayloadTooLarge),
            NullLogger<GlobalExceptionHandlingMiddleware>.Instance);
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status413PayloadTooLarge, context.Response.StatusCode);
        context.Response.Body.Position = 0;
        using var payload = await JsonDocument.ParseAsync(context.Response.Body);
        Assert.Equal("Request body is too large.", payload.RootElement.GetProperty("message").GetString());
        Assert.DoesNotContain("parser", payload.RootElement.GetRawText(), StringComparison.OrdinalIgnoreCase);
    }
}
