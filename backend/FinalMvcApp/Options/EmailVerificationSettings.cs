namespace FinalMvcApp.Options;

public class EmailVerificationSettings
{
    public const string SectionName = "EmailVerification";

    public int CodeLifetimeMinutes { get; set; } = 10;

    public int ResendCooldownSeconds { get; set; } = 60;

    public int MaxAttempts { get; set; } = 5;

    public string HmacKey { get; set; } = string.Empty;
}
