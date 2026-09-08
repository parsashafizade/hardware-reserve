using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class EmailVerificationCode
{
    public int Id { get; set; }

    [Required]
    public int UserId { get; set; }

    [Required]
    [StringLength(64)]
    public string CodeHash { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime ExpiresAt { get; set; }

    public DateTime? UsedAt { get; set; }

    public int AttemptCount { get; set; }

    public User User { get; set; } = null!;
}
