using FinalMvcApp.DTOs.Common;
using FinalMvcApp.Errors;
using FluentValidation;
using System.Text.Json;

namespace FinalMvcApp.Middleware;

public class GlobalExceptionHandlingMiddleware
{
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionHandlingMiddleware> _logger;

    public GlobalExceptionHandlingMiddleware(
        RequestDelegate next,
        ILogger<GlobalExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ValidationException exception)
        {
            _logger.LogWarning(
                exception,
                "Validation error on {Path}",
                context.Request.Path);

            var errors = exception.Errors
                .GroupBy(error => error.PropertyName)
                .ToDictionary(
                    group => group.Key,
                    group => group
                        .Select(error => error.ErrorMessage)
                        .ToArray());

            await WriteErrorAsync(
                context,
                StatusCodes.Status400BadRequest,
                "Validation failed.",
                errors);
        }
        catch (ApiException exception)
        {
            _logger.LogWarning(
                exception,
                "API error {Code} on {Path}",
                exception.Code,
                context.Request.Path);

            await WriteErrorAsync(
                context,
                exception.StatusCode,
                exception.Message,
                code: exception.Code);
        }
        catch (UnauthorizedAccessException exception)
        {
            _logger.LogWarning(
                exception,
                "Unauthorized request to {Path}",
                context.Request.Path);

            await WriteErrorAsync(
                context,
                StatusCodes.Status401Unauthorized,
                exception.Message);
        }
        catch (KeyNotFoundException exception)
        {
            _logger.LogWarning(
                exception,
                "Not found on {Path}",
                context.Request.Path);

            await WriteErrorAsync(
                context,
                StatusCodes.Status404NotFound,
                exception.Message);
        }
        catch (InvalidOperationException exception)
        {
            _logger.LogWarning(
                exception,
                "Business rule violation on {Path}",
                context.Request.Path);

            await WriteErrorAsync(
                context,
                StatusCodes.Status400BadRequest,
                exception.Message);
        }
        catch (BadHttpRequestException exception)
            when (exception.StatusCode ==
                  StatusCodes.Status413PayloadTooLarge)
        {
            _logger.LogWarning(
                "Rejected oversized request on {Path}",
                context.Request.Path);

            await WriteErrorAsync(
                context,
                StatusCodes.Status413PayloadTooLarge,
                "Request body is too large.");
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Unhandled exception on {Path}",
                context.Request.Path);

            await WriteErrorAsync(
                context,
                StatusCodes.Status500InternalServerError,
                "An unexpected error occurred.");
        }
    }

    private static async Task WriteErrorAsync(
        HttpContext context,
        int statusCode,
        string message,
        Dictionary<string, string[]>? errors = null,
        string? code = null)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";

        var response = new ErrorResponseDto
        {
            TraceId = context.TraceIdentifier,
            Code = code,
            Message = message,
            Errors = errors
        };

        var payload =
            JsonSerializer.Serialize(
                response,
                JsonOptions);

        await context.Response.WriteAsync(payload);
    }
}