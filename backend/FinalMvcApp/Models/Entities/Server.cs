using System.ComponentModel.DataAnnotations;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Models.Entities;

public class Server
{
    public int Id { get; set; }

    [Required]
    [StringLength(120)]
    public string CPU { get; set; } = string.Empty;

    [Required]
    [StringLength(120)]
    public string GPU { get; set; } = string.Empty;

    [Required]
    [StringLength(40)]
    public string RAM { get; set; } = string.Empty;

    [Required]
    [StringLength(40)]
    public string Storage { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string OS { get; set; } = string.Empty;

    [Range(typeof(decimal), "0.01", "9999999999999999.99")]
    public decimal PricePerHour { get; set; }

    [Range(typeof(decimal), "0.01", "9999999999999999.99")]
    public decimal PricePerDay { get; set; }

    public bool IsActive { get; set; } = true;

    public ServerOperationalStatus OperationalStatus { get; set; } = ServerOperationalStatus.Available;

    public bool FinderEligible { get; set; } = true;

    [Range(0, 100)]
    public int CpuCapabilityLevel { get; set; } = 50;

    [Range(0, 100)]
    public int GpuCapabilityLevel { get; set; }

    public ServerPerformanceTier PerformanceTier { get; set; } = ServerPerformanceTier.Standard;

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();

    public ICollection<ServerWorkloadCapability> WorkloadCapabilities { get; set; } = new List<ServerWorkloadCapability>();

    public ICollection<ServerMaintenanceWindow> MaintenanceWindows { get; set; } = new List<ServerMaintenanceWindow>();
}
