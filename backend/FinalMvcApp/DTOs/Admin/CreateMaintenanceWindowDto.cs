using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.DTOs.Admin;

public class CreateMaintenanceWindowDto
{
    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    [StringLength(300)]
    public string? Reason { get; set; }
}
