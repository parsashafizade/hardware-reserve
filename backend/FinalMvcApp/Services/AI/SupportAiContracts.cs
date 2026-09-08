namespace FinalMvcApp.Services.AI;

public enum SupportAiRequestMode
{
    UserResponse,
    ContextualResponse,
    AdminSuggestedReply
}

public enum SupportAiIntent
{
    GENERAL_SUPPORT,
    HARDWARE_SELECTION,
    RESERVATION,
    PRICING,
    PAYMENT,
    PROVISIONING,
    ACCOUNT,
    CANCELLATION,
    REFUND,
    HUMAN_REQUEST,
    PAYMENT_DISPUTE,
    MUTATION_REQUIRED,
    OUT_OF_SCOPE,
    UNKNOWN,
    PROMPT_INJECTION
}

public enum SupportAiAction
{
    ANSWER,
    REJECT,
    ESCALATE,
    RESOLVE
}

public enum SupportAccountCapability
{
    NONE,
    PUBLIC_SERVERS,
    RESERVATION_LIST,
    RESERVATION_DETAILS,
    PAYMENT_STATUS,
    PAID_SERVICES,
    PROVISIONING_STATUS
}

public sealed record SupportAiChatMessage(
    string SenderType,
    string Content,
    DateTime CreatedAt,
    long SequenceNumber);

public sealed class SupportAiProviderRequest
{
    public SupportAiRequestMode Mode { get; init; }

    public bool IsAuthenticated { get; init; }

    public string LatestUserMessage { get; init; } = string.Empty;

    public string ApprovedKnowledge { get; init; } = string.Empty;

    public IReadOnlyList<SupportAiChatMessage> Conversation { get; init; } = [];

    public SupportAccountContext? AccountContext { get; init; }
}

public sealed class SupportAiProviderDecision
{
    public SupportAiIntent Intent { get; init; } = SupportAiIntent.UNKNOWN;

    public SupportAiAction Action { get; init; } = SupportAiAction.ESCALATE;

    public SupportAccountCapability AccountCapability { get; init; }

    public int? ReservationId { get; init; }

    public double Confidence { get; init; }

    public string Reply { get; init; } = string.Empty;

    public string SuggestedTitle { get; init; } = string.Empty;

    public string HandoffSummary { get; init; } = string.Empty;
}

public sealed class SupportAccountContext
{
    public SupportAccountCapability Capability { get; init; }

    public bool RequiresAuthentication { get; init; }

    public bool RequestedReservationNotFound { get; init; }

    public IReadOnlyList<SupportReservationContext> Reservations { get; init; } = [];

    public IReadOnlyList<SupportServerContext> AvailableServers { get; init; } = [];
}

public sealed class SupportReservationContext
{
    public int ReservationId { get; init; }

    public string ReservationStatus { get; init; } = string.Empty;

    public string PaymentStatus { get; init; } = string.Empty;

    public DateTime? PaymentDate { get; init; }

    public DateTime StartTime { get; init; }

    public DateTime EndTime { get; init; }

    public decimal TotalPrice { get; init; }

    public bool CredentialsAssigned { get; init; }

    public SupportServerContext Server { get; init; } = new();
}

public sealed class SupportServerContext
{
    public int ServerId { get; init; }

    public string CPU { get; init; } = string.Empty;

    public string GPU { get; init; } = string.Empty;

    public string RAM { get; init; } = string.Empty;

    public string Storage { get; init; } = string.Empty;

    public string OS { get; init; } = string.Empty;

    public decimal PricePerHour { get; init; }

    public decimal PricePerDay { get; init; }
}

public sealed class SupportAiPolicyOutcome
{
    public string Reply { get; init; } = string.Empty;

    public bool Escalate { get; init; }

    public bool Resolve { get; init; }

    public string EscalationReason { get; init; } = string.Empty;

    public string HandoffSummary { get; init; } = string.Empty;
}

public sealed class SupportAiProviderException : Exception
{
    public SupportAiProviderException(string failureCode, int attemptCount, Exception? innerException = null)
        : base("The configured AI support provider could not complete the request.", innerException)
    {
        FailureCode = failureCode;
        AttemptCount = attemptCount;
    }

    public string FailureCode { get; }

    public int AttemptCount { get; }
}
