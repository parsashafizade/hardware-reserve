namespace FinalMvcApp.DTOs.Admin;

public class AdminNotificationHistoryItemDto
{
    public Guid Id { get; set; }

    public int UserId { get; set; }

    public string UserEmail { get; set; } = string.Empty;

    public string Source { get; set; } = string.Empty;

    public string Type { get; set; } = string.Empty;

    public string? Title { get; set; }

    public string? Message { get; set; }

    public string? ResourceLabel { get; set; }

    public int? ReservationId { get; set; }

    public Guid? SupportConversationId { get; set; }

    public Guid? AdminCampaignId { get; set; }

    public int? CreatedByAdminUserId { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ReadAt { get; set; }
}
