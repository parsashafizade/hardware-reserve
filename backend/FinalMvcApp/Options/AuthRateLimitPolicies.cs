namespace FinalMvcApp.Options;

public static class AuthRateLimitPolicies
{
    public const string Authentication = "AuthAuthentication";

    public const string CodeSend = "AuthCodeSend";

    public const string CodeVerify = "AuthCodeVerify";
}