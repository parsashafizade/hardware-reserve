namespace FinalMvcApp.Services.Interfaces;

public interface IEmailVerificationService
{
    Task<EmailVerificationIssueResult?> IssueCodeAsync(
        int userId,
        bool enforceResendCooldown,
        CancellationToken cancellationToken = default);

    Task ValidateAndConsumeAsync(
        int userId,
        string code,
        CancellationToken cancellationToken = default);
}
