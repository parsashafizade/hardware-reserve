namespace FinalMvcApp.DTOs.Servers;

public class UpdateServerDto
{
    public string CPU { get; set; } = string.Empty;

    public string GPU { get; set; } = string.Empty;

    public string RAM { get; set; } = string.Empty;

    public string Storage { get; set; } = string.Empty;

    public string OS { get; set; } = string.Empty;

    public decimal PricePerHour { get; set; }

    public decimal PricePerDay { get; set; }

    public bool IsActive { get; set; }

    public string OperationalStatus { get; set; } = "Available";

    public bool FinderEligible { get; set; } = true;

    public int CpuCapabilityLevel { get; set; } = 50;

    public int GpuCapabilityLevel { get; set; }

    public string PerformanceTier { get; set; } = "Standard";

    public IReadOnlyList<ServerWorkloadCapabilityDto> WorkloadCapabilities { get; set; } = [];
}
