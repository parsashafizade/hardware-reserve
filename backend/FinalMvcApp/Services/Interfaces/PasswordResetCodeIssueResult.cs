namespace FinalMvcApp.Services.Interfaces;

public sealed record PasswordResetCodeIssueResult(
    string Code,
    DateTime ExpiresAtUtc);