namespace FinalMvcApp.Services.Interfaces;

public sealed record EmailVerificationIssueResult(
    string Code,
    DateTime ExpiresAtUtc);
