using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class UserNotification
{
    public Guid Id { get; set; }

    public int UserId { get; set; }

    [Required]
    public UserNotificationType Type { get; set; }

    public UserNotificationSource Source { get; set; } = UserNotificationSource.System;

    [Required]
    [StringLength(200)]
    public string DeduplicationKey { get; set; } = string.Empty;

    [StringLength(160)]
    public string? ResourceLabel { get; set; }

    [StringLength(120)]
    public string? Title { get; set; }

    [StringLength(1000)]
    public string? Message { get; set; }

    public int? ReservationId { get; set; }

    public Guid? SupportConversationId { get; set; }

    public Guid? AdminCampaignId { get; set; }

    public int? CreatedByAdminUserId { get; set; }

    public DateTime? EventTime { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ReadAt { get; set; }

    public User User { get; set; } = null!;

    public Reservation? Reservation { get; set; }

    public SupportConversation? SupportConversation { get; set; }

    public AdminNotificationCampaign? AdminCampaign { get; set; }

    public User? CreatedByAdminUser { get; set; }
}
