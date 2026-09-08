using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class AdminNotificationCampaign
{
    public Guid Id { get; set; }

    public int CreatedByAdminUserId { get; set; }

    public AdminNotificationRecipientScope RecipientScope { get; set; }

    public int? RecipientUserId { get; set; }

    [Required]
    [StringLength(120)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [StringLength(1000)]
    public string Message { get; set; } = string.Empty;

    [Required]
    [StringLength(40)]
    public string Category { get; set; } = "General";

    public int TargetCount { get; set; }

    public DateTime CreatedAt { get; set; }

    public User CreatedByAdminUser { get; set; } = null!;

    public User? RecipientUser { get; set; }

    public ICollection<UserNotification> Notifications { get; set; } = new List<UserNotification>();
}
