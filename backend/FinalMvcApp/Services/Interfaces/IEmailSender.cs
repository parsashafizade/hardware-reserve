namespace FinalMvcApp.Services.Interfaces;

public interface IEmailSender
{
    Task SendPasswordResetCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default);

    Task SendEmailVerificationCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default);

    Task SendCurrentEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default);

    Task SendNewEmailChangeCodeAsync(
        string toEmail,
        string fullName,
        string code,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken = default);
}
