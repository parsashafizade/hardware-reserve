using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class ConsoleEmailSender : IEmailSender
{
    private readonly ILogger<ConsoleEmailSender> _logger;

    public ConsoleEmailSender(ILogger<ConsoleEmailSender> logger)
    {
        _logger = logger;
    }

    public Task SendPasswordResetCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Symbolic password reset email generated for {Email} ({FullName}); expires at {ExpiresAtUtc} UTC.",
            toEmail,
            fullName,
            expiresAtUtc);

        return Task.CompletedTask;
    }
    public Task SendEmailVerificationCodeAsync(
    string toEmail,
    string fullName,
    string code,
    DateTime expiresAtUtc,
    CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Symbolic verification email generated for {Email} ({FullName}); expires at {ExpiresAtUtc} UTC.",
            toEmail,
            fullName,
            expiresAtUtc);

        return Task.CompletedTask;
    }

    public Task SendCurrentEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Symbolic current-email confirmation generated for {Email} ({FullName}); expires at {ExpiresAtUtc} UTC.",
            toEmail,
            fullName,
            expiresAtUtc);

        return Task.CompletedTask;
    }

    public Task SendNewEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Symbolic new-email verification generated for {Email} ({FullName}); expires at {ExpiresAtUtc} UTC.",
            toEmail,
            fullName,
            expiresAtUtc);

        return Task.CompletedTask;
    }
}
