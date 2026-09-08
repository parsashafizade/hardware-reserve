namespace FinalMvcApp.Models.Enums;

public enum SupportAuditEventType
{
    ConversationCreated = 1,
    AdminHandoffRequested = 2,
    AdminClaimed = 3,
    Resolved = 4,
    Reopened = 5,
    Closed = 6,
    TitleChanged = 7,
    RealtimeDeliveryFailed = 8,
    AiEscalated = 9,
    AiResolved = 10,
    AiTitleGenerated = 11,
    AiProcessingFailed = 12
}
