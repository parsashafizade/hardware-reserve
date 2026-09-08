using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class PendingEmailChange
{
    public Guid Id { get; set; }

    public int UserId { get; set; }

    [Required]
    [StringLength(320)]
    public string CurrentEmail { get; set; } = string.Empty;

    [Required]
    [StringLength(320)]
    public string NewEmail { get; set; } = string.Empty;

    [Required]
    [StringLength(64)]
    public string CurrentCodeHash { get; set; } = string.Empty;

    [Required]
    [StringLength(64)]
    public string NewCodeHash { get; set; } = string.Empty;

    public DateTime CurrentCodeCreatedAt { get; set; }

    public DateTime NewCodeCreatedAt { get; set; }

    public DateTime CurrentCodeExpiresAt { get; set; }

    public DateTime NewCodeExpiresAt { get; set; }

    public DateTime? CurrentCodeUsedAt { get; set; }

    public DateTime? NewCodeUsedAt { get; set; }

    public int CurrentAttemptCount { get; set; }

    public int NewAttemptCount { get; set; }

    public DateTime? CurrentEmailVerifiedAt { get; set; }

    public DateTime? NewEmailVerifiedAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public DateTime ExpiresAt { get; set; }

    public DateTime? CompletedAt { get; set; }

    public DateTime? InvalidatedAt { get; set; }

    public User User { get; set; } = null!;
}
