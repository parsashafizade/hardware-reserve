using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.DTOs.Admin;

public class AdminSendNotificationDto
{
    [Required]
    public string RecipientScope { get; set; } = "User";

    public int? UserId { get; set; }

    public IReadOnlyList<int>? UserIds { get; set; } = [];

    [Required]
    [StringLength(120, MinimumLength = 2)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [StringLength(1000, MinimumLength = 2)]
    public string Message { get; set; } = string.Empty;

    [Required]
    [StringLength(40)]
    public string Category { get; set; } = "General";

    public bool ConfirmBroadcast { get; set; }
}
