namespace FinalMvcApp.DTOs.Admin;

public class AdminMaintenanceWindowDto
{
    public Guid Id { get; set; }

    public int ServerId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public string? Reason { get; set; }

    public DateTime CreatedAt { get; set; }
}
