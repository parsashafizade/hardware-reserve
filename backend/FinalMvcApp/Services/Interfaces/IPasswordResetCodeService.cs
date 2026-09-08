namespace FinalMvcApp.Services.Interfaces;

public interface IPasswordResetCodeService
{
    Task<PasswordResetCodeIssueResult?> IssueCodeAsync(
        int userId,
        bool enforceCooldown,
        CancellationToken cancellationToken = default);

    Task ValidateAndConsumeAsync(
        int userId,
        string code,
        CancellationToken cancellationToken = default);
}