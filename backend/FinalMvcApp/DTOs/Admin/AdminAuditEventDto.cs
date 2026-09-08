namespace FinalMvcApp.DTOs.Admin;

public class AdminAuditEventDto
{
    public Guid Id { get; set; }

    public int AdminUserId { get; set; }

    public string Action { get; set; } = string.Empty;

    public string EntityType { get; set; } = string.Empty;

    public string EntityId { get; set; } = string.Empty;

    public string? Details { get; set; }

    public DateTime CreatedAt { get; set; }
}
