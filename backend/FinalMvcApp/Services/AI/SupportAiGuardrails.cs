using System.Text.RegularExpressions;

namespace FinalMvcApp.Services.AI;

public static partial class SupportAiGuardrails
{
    public static bool IsAccountCapabilityAllowed(
        SupportAiIntent intent,
        SupportAccountCapability capability)
    {
        return capability switch
        {
            SupportAccountCapability.NONE => true,
            SupportAccountCapability.PUBLIC_SERVERS => intent is
                SupportAiIntent.GENERAL_SUPPORT or
                SupportAiIntent.HARDWARE_SELECTION or
                SupportAiIntent.PRICING,
            SupportAccountCapability.RESERVATION_LIST => intent is
                SupportAiIntent.RESERVATION or
                SupportAiIntent.ACCOUNT,
            SupportAccountCapability.RESERVATION_DETAILS => intent is
                SupportAiIntent.RESERVATION or
                SupportAiIntent.PAYMENT or
                SupportAiIntent.PROVISIONING or
                SupportAiIntent.ACCOUNT,
            SupportAccountCapability.PAYMENT_STATUS => intent is
                SupportAiIntent.PAYMENT or
                SupportAiIntent.ACCOUNT,
            SupportAccountCapability.PAID_SERVICES => intent is
                SupportAiIntent.PROVISIONING or
                SupportAiIntent.ACCOUNT,
            SupportAccountCapability.PROVISIONING_STATUS => intent is
                SupportAiIntent.PROVISIONING or
                SupportAiIntent.ACCOUNT,
            _ => false
        };
    }

    public static bool IsPredominantlyPersian(string text)
    {
        var persianRuns = PersianTextRegex().Matches(text).Count;
        var latinRuns = LatinTextRegex().Matches(text).Count;
        return persianRuns > 0 && persianRuns >= latinRuns;
    }

    public static bool IsPromptInjectionAttempt(string text)
    {
        return PromptInjectionRegex().IsMatch(text);
    }

    public static bool IsRefundRequest(string text)
    {
        return RefundRegex().IsMatch(text);
    }

    public static bool IsHumanSupportRequest(string text)
    {
        return HumanSupportRegex().IsMatch(text);
    }

    public static bool IsCancellationRequest(string text)
    {
        return CancellationRegex().IsMatch(text);
    }

    public static bool IsCredentialDisclosureRequest(string text)
    {
        return CredentialDisclosureRegex().IsMatch(text);
    }

    public static bool ContainsForbiddenMutationClaim(string text)
    {
        return ForbiddenMutationClaimRegex().IsMatch(text);
    }

    public static string RedactSensitiveData(string value)
    {
        var redacted = PrivateKeyRegex().Replace(value, "[REDACTED_PRIVATE_KEY]");
        redacted = JwtRegex().Replace(redacted, "[REDACTED_TOKEN]");
        redacted = BearerTokenRegex().Replace(redacted, "$1[REDACTED_TOKEN]");
        redacted = SensitiveQueryValueRegex().Replace(redacted, "$1[REDACTED]");
        redacted = LabeledSecretRegex().Replace(redacted, "$1[REDACTED]");
        redacted = PersianLabeledSecretRegex().Replace(redacted, "$1[REDACTED]");
        return redacted;
    }

    [GeneratedRegex(@"[\u0600-\u06FF]+", RegexOptions.CultureInvariant)]
    private static partial Regex PersianTextRegex();

    [GeneratedRegex(@"[A-Za-z]+", RegexOptions.CultureInvariant)]
    private static partial Regex LatinTextRegex();

    [GeneratedRegex(
        @"(?:ignore\s+(?:all\s+|any\s+|the\s+)?(?:previous|prior|system|developer)\s+(?:instructions?|messages?|prompts?)|(?:reveal|show|print|repeat|extract)\s+(?:your\s+)?(?:hidden\s+|system\s+|developer\s+)?(?:prompt|instructions?|message)|system\s+prompt|developer\s+message|(?:دستور(?:ها|های)?\s+قبلی|دستورالعمل(?:‌|\s*)های\s+قبلی).{0,20}نادیده|پرامپت\s+سیستم|دستورالعمل(?:‌|\s*)های\s+سیستم|متن\s+پرامپت)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex PromptInjectionRegex();

    [GeneratedRegex(
        @"(?:\brefund\b|\bchargeback\b|money\s+back|بازپرداخت|استرداد(?:\s|‌)*وجه|پس(?:\s|‌)*گرفتن(?:\s|‌)*پول)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex RefundRegex();

    [GeneratedRegex(
        @"(?:(?:talk|speak|connect|transfer|escalate).{0,40}\b(?:human|person|agent|admin(?:istrator)?)\b|\b(?:human|person|agent|admin(?:istrator)?)\b.{0,40}(?:talk|speak|connect|help|support)|human\s+support|(?:صحبت|وصل|ارتباط).{0,30}(?:انسان|آدم|اپراتور|ادمین|پشتیبان)|(?:پشتیبان(?:\s|‌)*انسانی|اپراتور|ادمین).{0,30}(?:می(?:\s|‌)*خواهم|می(?:\s|‌)*خوام|صحبت|وصل))",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex HumanSupportRegex();

    [GeneratedRegex(
        @"(?:\b(?:cancel|cancellation)\b.{0,60}\b(?:reservation|booking)\b|\b(?:reservation|booking)\b.{0,60}\b(?:cancel|cancellation)\b|لغو.{0,30}رزرو|رزرو.{0,30}لغو)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex CancellationRegex();

    [GeneratedRegex(
        @"(?:(?:show|tell|give|reveal|send|what\s+is).{0,50}(?:password|access\s+token|refresh\s+token|reset\s+token|api\s+key|secret|credentials)|(?:password|access\s+token|refresh\s+token|reset\s+token|api\s+key|credentials).{0,50}(?:show|tell|give|reveal|send)|(?:رمز(?:\s|‌)*عبور|توکن|اطلاعات(?:\s|‌)*دسترسی).{0,35}(?:بگو|بده|نمایش|چیست|چیه)|(?:بگو|بده|نمایش).{0,35}(?:رمز(?:\s|‌)*عبور|توکن|اطلاعات(?:\s|‌)*دسترسی))",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex CredentialDisclosureRegex();

    [GeneratedRegex(
        @"(?:\b(?:i|we)(?:'ve|\s+have)?\s+(?:cancelled|canceled|refunded|approved|rejected|modified|changed|assigned|issued)\b.{0,80}\b(?:reservation|refund|payment|credentials?|account|password)\b|(?:رزرو|بازپرداخت|پرداخت|اطلاعات(?:\s|‌)*دسترسی|حساب).{0,50}(?:لغو\s+کردم|تغییر\s+دادم|تخصیص\s+دادم|تأیید\s+کردم|رد\s+کردم))",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex ForbiddenMutationClaimRegex();

    [GeneratedRegex(
        @"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex PrivateKeyRegex();

    [GeneratedRegex(
        @"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
        RegexOptions.CultureInvariant,
        100)]
    private static partial Regex JwtRegex();

    [GeneratedRegex(
        @"(?i)(\bBearer\s+)[A-Za-z0-9._~+/=-]{8,}",
        RegexOptions.CultureInvariant,
        100)]
    private static partial Regex BearerTokenRegex();

    [GeneratedRegex(
        @"(?i)([?&](?:access_token|refresh_token|reset_token|token|api_key|key)=)[^&#\s]+",
        RegexOptions.CultureInvariant,
        100)]
    private static partial Regex SensitiveQueryValueRegex();

    [GeneratedRegex(
        @"(?i)(\b(?:password|passwd|pwd|access[_\s-]*token|refresh[_\s-]*token|reset[_\s-]*token|api[_\s-]*key|secret)\s*[:=]\s*)[^\s,;]+",
        RegexOptions.CultureInvariant,
        100)]
    private static partial Regex LabeledSecretRegex();

    [GeneratedRegex(
        @"((?:رمز(?:\s|‌)*عبور|توکن(?:\s|‌)*(?:دسترسی|بازیابی)?|کلید(?:\s|‌)*API)\s*[:=]\s*)[^\s،؛]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
        100)]
    private static partial Regex PersianLabeledSecretRegex();
}
