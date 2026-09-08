using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class RefreshToken
{
    public Guid Id { get; set; }

    [Required]
    public int UserId { get; set; }

    [Required]
    [StringLength(256)]
    public string Token { get; set; } = string.Empty;

    [Required]
    public DateTime ExpiresAt { get; set; }

    public DateTime? RevokedAt { get; set; }

    [Required]
    public DateTime CreatedAt { get; set; }

    [Required]
    [StringLength(64)]
    public string CreatedByIp { get; set; } = string.Empty;

    public User User { get; set; } = null!;

    public bool IsActive => RevokedAt is null && ExpiresAt > DateTime.UtcNow;
}
