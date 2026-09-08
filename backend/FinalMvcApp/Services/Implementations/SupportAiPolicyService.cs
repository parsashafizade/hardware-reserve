using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Options;
using System.Globalization;

namespace FinalMvcApp.Services.Implementations;

public class SupportAiPolicyService : ISupportAiPolicyService
{
    private readonly double _minimumConfidence;
    private readonly TimeProvider _timeProvider;

    public SupportAiPolicyService(IOptions<SupportAiOptions> options, TimeProvider timeProvider)
    {
        _minimumConfidence = options.Value.MinimumConfidence;
        _timeProvider = timeProvider;
    }

    public SupportAiPolicyOutcome? EvaluateDeterministicMessage(string latestUserMessage)
    {
        var persian = SupportAiGuardrails.IsPredominantlyPersian(latestUserMessage);

        if (SupportAiGuardrails.IsRefundRequest(latestUserMessage))
        {
            return Escalate(
                persian
                    ? "درخواست‌های بازپرداخت باید توسط تیم پشتیبانی بررسی شوند. این گفتگو برای بررسی انسانی ارسال شد و هنوز هیچ تصمیمی درباره بازپرداخت گرفته نشده است."
                    : "Refund requests require Support Team review. I have sent this conversation for human review; no refund decision has been made.",
                "REFUND_REVIEW",
                $"Refund review requested. User issue: {SafeIssue(latestUserMessage, 700)}");
        }

        if (SupportAiGuardrails.IsHumanSupportRequest(latestUserMessage))
        {
            return Escalate(
                persian
                    ? "این گفتگو برای ادامه بررسی به تیم پشتیبانی ارسال شد."
                    : "I have sent this conversation to the Support Team for human assistance.",
                "HUMAN_REQUESTED",
                $"User requested human support. User issue: {SafeIssue(latestUserMessage, 700)}");
        }

        if (SupportAiGuardrails.IsPromptInjectionAttempt(latestUserMessage))
        {
            return Answer(persian
                ? "من نمی‌توانم دستورالعمل‌های داخلی یا پرامپت سیستم را ارائه یا نادیده بگیرم. فقط درباره خدمات HardwareReserve راهنمایی می‌کنم."
                : "I cannot reveal or override internal instructions. I can only help with HardwareReserve support topics.");
        }

        if (SupportAiGuardrails.IsCancellationRequest(latestUserMessage))
        {
            return Answer(persian
                ? "لغو رزرو پشتیبانی نمی‌شود. اگر موضوع شما اختلاف پرداخت یا درخواست بازپرداخت است، آن را جداگانه مطرح کنید تا تیم پشتیبانی بررسی کند."
                : "Reservation cancellation is not supported. If this involves a payment dispute or refund request, raise that separately so the Support Team can review it.");
        }

        if (SupportAiGuardrails.IsCredentialDisclosureRequest(latestUserMessage))
        {
            return Answer(persian
                ? "برای امنیت، رمزها و توکن‌ها در گفتگو نمایش داده نمی‌شوند. اطلاعات اتصال تخصیص‌یافته را در My Services ببینید و برای رمز حساب از فرایند بازیابی رمز استفاده کنید."
                : "For security, passwords and tokens are never shown in chat. View assigned connection details in My Services, or use account password recovery for your login password.");
        }

        return null;
    }

    public SupportAiPolicyOutcome Evaluate(
        SupportAiProviderDecision decision,
        SupportAccountContext? accountContext,
        string latestUserMessage,
        bool isAuthenticated)
    {
        var deterministicOutcome = EvaluateDeterministicMessage(latestUserMessage);
        if (deterministicOutcome is not null)
        {
            return deterministicOutcome;
        }

        var persian = IsPredominantlyPersian(latestUserMessage);

        if (!SupportAiGuardrails.IsAccountCapabilityAllowed(decision.Intent, decision.AccountCapability))
        {
            return Escalate(
                persian
                    ? "برای حفظ امنیت حساب، این درخواست برای بررسی به تیم پشتیبانی ارسال شد."
                    : "To protect account data, I have sent this request to the Support Team for review.",
                "ACCOUNT_CAPABILITY_REJECTED",
                $"The AI requested an account capability that is not allowed for intent {decision.Intent}.");
        }

        if (decision.Intent == SupportAiIntent.CANCELLATION)
        {
            return Answer(persian
                ? "لغو رزرو پشتیبانی نمی‌شود. اگر موضوع شما اختلاف پرداخت یا درخواست بازپرداخت است، آن را جداگانه مطرح کنید تا تیم پشتیبانی بررسی کند."
                : "Reservation cancellation is not supported. If this involves a payment dispute or refund request, raise that separately so the Support Team can review it.");
        }

        if (decision.Intent == SupportAiIntent.REFUND)
        {
            return Escalate(
                persian
                    ? "درخواست‌های بازپرداخت باید توسط تیم پشتیبانی بررسی شوند. این گفتگو برای بررسی انسانی ارسال شد و هنوز هیچ تصمیمی درباره بازپرداخت گرفته نشده است."
                    : "Refund requests require Support Team review. I have sent this conversation for human review; no refund decision has been made.",
                "REFUND_REVIEW",
                BuildSummary("Refund review requested", decision, latestUserMessage));
        }

        if (decision.Intent == SupportAiIntent.HUMAN_REQUEST)
        {
            return Escalate(
                persian
                    ? "این گفتگو برای ادامه بررسی به تیم پشتیبانی ارسال شد."
                    : "I have sent this conversation to the Support Team for human assistance.",
                "HUMAN_REQUESTED",
                BuildSummary("User requested human support", decision, latestUserMessage));
        }

        if (decision.Intent is SupportAiIntent.PAYMENT_DISPUTE or SupportAiIntent.MUTATION_REQUIRED)
        {
            return Escalate(
                persian
                    ? "این درخواست به بررسی و اقدام تیم پشتیبانی نیاز دارد و برای بررسی انسانی ارسال شد."
                    : "This request requires Support Team review or action, so I have sent it for human assistance.",
                decision.Intent.ToString(),
                BuildSummary("Human domain action required", decision, latestUserMessage));
        }

        if (decision.Intent is SupportAiIntent.OUT_OF_SCOPE or SupportAiIntent.PROMPT_INJECTION)
        {
            return Answer(persian
                ? "من فقط درباره سخت‌افزار، رزرو، قیمت، پرداخت، آماده‌سازی سرویس و حساب HardwareReserve راهنمایی می‌کنم."
                : "I can only help with HardwareReserve hardware, reservations, pricing, payments, provisioning, services, and account support.");
        }

        if (accountContext?.RequiresAuthentication == true)
        {
            return Answer(persian
                ? "برای دریافت اطلاعات مربوط به رزرو، پرداخت یا سرویس خود وارد حساب HardwareReserve شوید. مهمان‌ها فقط می‌توانند پشتیبانی عمومی محصول دریافت کنند."
                : "Sign in to HardwareReserve for reservation, payment, or service-specific assistance. Guests can only receive general product support.");
        }

        if (accountContext?.RequestedReservationNotFound == true)
        {
            return Answer(persian
                ? "این رزرو در حساب واردشده پیدا نشد. شناسه رزرو را در بخش My Reservations بررسی کنید."
                : "I could not find that reservation in the signed-in account. Check the reservation ID in My Reservations.");
        }

        if (decision.Intent == SupportAiIntent.PROVISIONING && accountContext is not null)
        {
            var provisioning = EvaluateProvisioning(accountContext, persian, decision, latestUserMessage);
            if (provisioning is not null)
            {
                return provisioning;
            }
        }

        if (decision.Intent == SupportAiIntent.UNKNOWN
            || decision.Confidence < _minimumConfidence
            || decision.Action == SupportAiAction.ESCALATE)
        {
            return Escalate(
                persian
                    ? "برای جلوگیری از ارائه پاسخ نادرست، این گفتگو برای بررسی به تیم پشتیبانی ارسال شد."
                    : "To avoid giving you an unreliable answer, I have sent this conversation to the Support Team for review.",
                "INSUFFICIENT_CONFIDENCE",
                BuildSummary("Approved knowledge was insufficient", decision, latestUserMessage));
        }

        if (SupportAiGuardrails.ContainsForbiddenMutationClaim(decision.Reply))
        {
            return Escalate(
                persian
                    ? "پشتیبانی خودکار اجازه انجام این تغییر را ندارد. این گفتگو برای بررسی انسانی ارسال شد."
                    : "Automated support cannot perform that change. I have sent this conversation for human review.",
                "FORBIDDEN_AI_MUTATION_CLAIM",
                BuildSummary("AI attempted to claim a forbidden domain mutation", decision, latestUserMessage));
        }

        var reply = NormalizeReply(decision.Reply);
        if (string.IsNullOrWhiteSpace(reply))
        {
            return Escalate(
                persian
                    ? "برای بررسی دقیق‌تر، این گفتگو به تیم پشتیبانی ارسال شد."
                    : "I have sent this conversation to the Support Team for a reliable answer.",
                "EMPTY_PROVIDER_REPLY",
                BuildSummary("AI returned no usable support reply", decision, latestUserMessage));
        }

        return new SupportAiPolicyOutcome
        {
            Reply = reply,
            Resolve = decision.Action == SupportAiAction.RESOLVE
        };
    }

    public string BuildProviderFailureReply(string latestUserMessage)
    {
        return IsPredominantlyPersian(latestUserMessage)
            ? "پشتیبانی خودکار در حال حاضر در دسترس نیست. گفتگوی شما برای ادامه بررسی به تیم پشتیبانی ارسال شد."
            : "Automated support is temporarily unavailable. Your conversation has been sent to the Support Team for follow-up.";
    }

    public string BuildProviderFailureSummary(string failureCode, string latestUserMessage)
    {
        return $"Automated support failed ({failureCode}). Latest user issue: {SafeIssue(latestUserMessage, 500)}";
    }

    private SupportAiPolicyOutcome? EvaluateProvisioning(
        SupportAccountContext context,
        bool persian,
        SupportAiProviderDecision decision,
        string latestUserMessage)
    {
        var paidReservations = context.Reservations
            .Where(item => string.Equals(item.ReservationStatus, ReservationStatus.Paid.ToString(), StringComparison.OrdinalIgnoreCase)
                && string.Equals(item.PaymentStatus, PaymentStatus.Completed.ToString(), StringComparison.OrdinalIgnoreCase))
            .ToList();

        var overdue = paidReservations.FirstOrDefault(item => !item.CredentialsAssigned
            && item.PaymentDate.HasValue
            && _timeProvider.GetUtcNow().UtcDateTime - item.PaymentDate.Value.ToUniversalTime() > TimeSpan.FromHours(24));

        if (overdue is not null)
        {
            var elapsed = _timeProvider.GetUtcNow().UtcDateTime - overdue.PaymentDate!.Value.ToUniversalTime();
            return Escalate(
                persian
                    ? "بیش از ۲۴ ساعت از پرداخت موفق گذشته و اطلاعات دسترسی هنوز تخصیص داده نشده است. این گفتگو برای پیگیری به تیم پشتیبانی ارسال شد."
                    : "More than 24 hours have passed since successful payment and credentials are still unassigned. I have sent this conversation to the Support Team for follow-up.",
                "PROVISIONING_OVERDUE",
                $"Reservation {overdue.ReservationId} is paid, credentials are not assigned, and provisioning is overdue by approximately {Math.Floor(elapsed.TotalHours).ToString(CultureInfo.InvariantCulture)} hours. {BuildSummary("Provisioning delay", decision, latestUserMessage)}");
        }

        if (paidReservations.Any(item => item.CredentialsAssigned))
        {
            return Answer(persian
                ? "اطلاعات دسترسی سرویس تخصیص داده شده است. برای مشاهده امن آن به بخش My Services بروید."
                : "Your service credentials have been assigned. View them securely in My Services.");
        }

        if (paidReservations.Count > 0)
        {
            return Answer(persian
                ? "اطلاعات دسترسی معمولاً بین ۱۰ دقیقه تا ۲۴ ساعت پس از پرداخت موفق تخصیص داده می‌شود. پس از تخصیص، آن را به‌صورت امن در My Services مشاهده کنید."
                : "Credentials are normally assigned within 10 minutes to 24 hours after successful payment. Once assigned, view them securely in My Services.");
        }

        return null;
    }

    private static SupportAiPolicyOutcome Answer(string reply)
    {
        return new SupportAiPolicyOutcome { Reply = reply };
    }

    private static SupportAiPolicyOutcome Escalate(
        string reply,
        string reason,
        string summary)
    {
        return new SupportAiPolicyOutcome
        {
            Reply = reply,
            Escalate = true,
            EscalationReason = reason,
            HandoffSummary = Truncate(summary, 2000)
        };
    }

    private static string BuildSummary(
        string prefix,
        SupportAiProviderDecision decision,
        string latestUserMessage)
    {
        var providerSummary = NormalizeReply(decision.HandoffSummary);
        return string.IsNullOrWhiteSpace(providerSummary)
            ? $"{prefix}. User issue: {SafeIssue(latestUserMessage, 700)}"
            : $"{prefix}. {Truncate(providerSummary, 1200)}";
    }

    private static string NormalizeReply(string value)
    {
        var normalized = SupportAiGuardrails.RedactSensitiveData(
            value.Replace("\0", string.Empty, StringComparison.Ordinal)).Trim();
        return Truncate(normalized, 4000);
    }

    private static bool IsPredominantlyPersian(string text)
    {
        return SupportAiGuardrails.IsPredominantlyPersian(text);
    }

    private static string Truncate(string value, int maxLength)
    {
        return value.Length <= maxLength ? value : value[..maxLength];
    }

    private static string SafeIssue(string value, int maxLength)
    {
        return Truncate(SupportAiGuardrails.RedactSensitiveData(value), maxLength);
    }
}
