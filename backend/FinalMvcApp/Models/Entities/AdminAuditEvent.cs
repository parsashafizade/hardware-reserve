using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class AdminAuditEvent
{
    public Guid Id { get; set; }

    public int AdminUserId { get; set; }

    public AdminAuditAction Action { get; set; }

    [Required]
    [StringLength(50)]
    public string EntityType { get; set; } = string.Empty;

    [Required]
    [StringLength(80)]
    public string EntityId { get; set; } = string.Empty;

    [StringLength(500)]
    public string? Details { get; set; }

    public DateTime CreatedAt { get; set; }

    public User AdminUser { get; set; } = null!;
}
