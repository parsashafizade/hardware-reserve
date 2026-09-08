namespace FinalMvcApp.DTOs.Admin;

public class AdminNotificationCampaignDto
{
    public Guid Id { get; set; }

    public int CreatedByAdminUserId { get; set; }

    public string RecipientScope { get; set; } = string.Empty;

    public int? RecipientUserId { get; set; }

    public string? RecipientEmail { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public int TargetCount { get; set; }

    public DateTime CreatedAt { get; set; }
}
