namespace FinalMvcApp.DTOs.Servers;

public class ServerDto
{
    public int Id { get; set; }

    public string CPU { get; set; } = string.Empty;

    public string GPU { get; set; } = string.Empty;

    public string RAM { get; set; } = string.Empty;

    public string Storage { get; set; } = string.Empty;

    public string OS { get; set; } = string.Empty;

    public decimal PricePerHour { get; set; }

    public decimal PricePerDay { get; set; }

    public bool IsActive { get; set; }

    public string OperationalStatus { get; set; } = string.Empty;

    public bool FinderEligible { get; set; }

    public int CpuCapabilityLevel { get; set; }

    public int GpuCapabilityLevel { get; set; }

    public string PerformanceTier { get; set; } = string.Empty;

    public IReadOnlyList<ServerWorkloadCapabilityDto> WorkloadCapabilities { get; set; } = [];
}
