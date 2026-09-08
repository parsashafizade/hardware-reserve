using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Models.Entities;

public class ServerWorkloadCapability
{
    public int ServerId { get; set; }

    public ServerWorkloadType WorkloadType { get; set; }

    public byte SuitabilityLevel { get; set; }

    public Server Server { get; set; } = null!;
}
