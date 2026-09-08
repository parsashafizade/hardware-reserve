using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Services.Interfaces;

public sealed record UserNotificationRequest(
    int UserId,
    UserNotificationType Type,
    string DeduplicationKey,
    string? ResourceLabel = null,
    int? ReservationId = null,
    Guid? SupportConversationId = null,
    DateTime? EventTime = null,
    string? Title = null,
    string? Message = null,
    UserNotificationSource Source = UserNotificationSource.System,
    Guid? AdminCampaignId = null,
    int? CreatedByAdminUserId = null);
