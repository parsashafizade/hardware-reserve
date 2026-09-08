using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class ServerMaintenanceWindow
{
    public Guid Id { get; set; }

    public int ServerId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    [StringLength(300)]
    public string? Reason { get; set; }

    public int CreatedByAdminUserId { get; set; }

    public DateTime CreatedAt { get; set; }

    public Server Server { get; set; } = null!;

    public User CreatedByAdminUser { get; set; } = null!;
}
