using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Data.Seed;

public static class ServerSeeder
{
    private const decimal DailyRateHours = 18m;

    public static async Task SeedAsync(ApplicationDbContext dbContext, CancellationToken cancellationToken = default)
    {
        var seededServers = GetSeededServers();
        var existingServers = await dbContext.Servers
            .Include(server => server.WorkloadCapabilities)
            .ToListAsync(cancellationToken);

        foreach (var seed in seededServers)
        {
            var match = existingServers.FirstOrDefault(server =>
                server.CPU == seed.CPU
                && server.GPU == seed.GPU
                && server.RAM == seed.RAM
                && server.Storage == seed.Storage
                && server.OS == seed.OS);

            if (match is null)
            {
                await dbContext.Servers.AddAsync(seed, cancellationToken);
            }
            else
            {
                match.PricePerHour = seed.PricePerHour;
                match.PricePerDay = seed.PricePerDay;
                if (match.WorkloadCapabilities.Count == 0)
                {
                    ApplyDefaultMetadata(match);
                }
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static List<Server> GetSeededServers()
    {
        return
        [
            CreateSeed("Intel Xeon Silver 4314", "None", "32GB", "1TB SSD", "Ubuntu 22.04", 24_000m),
            CreateSeed("Intel Xeon Gold 6330", "NVIDIA T4 16GB", "64GB", "1TB NVMe", "Ubuntu 22.04", 55_000m),
            CreateSeed("AMD EPYC 7543", "NVIDIA RTX 3080 10GB", "64GB", "2TB NVMe", "Ubuntu 24.04", 75_000m),
            CreateSeed("AMD EPYC 7763", "NVIDIA A10 24GB", "128GB", "2TB NVMe", "Ubuntu 22.04", 135_000m),
            CreateSeed("Intel Xeon W-2295", "NVIDIA RTX 3070 8GB", "32GB", "1TB SSD", "Windows Server 2022", 60_000m),
            CreateSeed("Intel Core i9-13900K", "NVIDIA RTX 3090 24GB", "64GB", "2TB NVMe", "Ubuntu 24.04", 105_000m),
            CreateSeed("AMD Ryzen 9 7950X", "NVIDIA RTX 4070 Ti 12GB", "64GB", "1TB NVMe", "Ubuntu 24.04", 85_000m),
            CreateSeed("Intel Xeon Gold 6248R", "NVIDIA V100 16GB", "128GB", "2TB NVMe", "Ubuntu 22.04", 125_000m),
            CreateSeed("AMD EPYC 7302", "None", "16GB", "512GB SSD", "Ubuntu 22.04", 12_000m),
            CreateSeed("Intel Xeon E-2288G", "NVIDIA GTX 1660 6GB", "32GB", "1TB SSD", "Windows Server 2022", 28_000m),
            CreateSeed("AMD EPYC 7513", "NVIDIA A100 40GB", "128GB", "2TB NVMe", "Ubuntu 22.04", 260_000m),
            CreateSeed("Intel Xeon Gold 6354", "NVIDIA L4 24GB", "64GB", "1TB NVMe", "Ubuntu 24.04", 120_000m),
            CreateSeed("AMD Ryzen 7 7700X", "NVIDIA RTX 3060 12GB", "32GB", "1TB NVMe", "Ubuntu 22.04", 45_000m),
            CreateSeed("Intel Core i7-12700K", "None", "16GB", "512GB SSD", "Ubuntu 24.04", 15_000m),
            CreateSeed("AMD EPYC 9654", "NVIDIA H100 80GB", "256GB", "4TB NVMe", "Ubuntu 24.04", 520_000m)
        ];
    }

    private static Server CreateSeed(
        string cpu,
        string gpu,
        string ram,
        string storage,
        string os,
        decimal pricePerHour)
    {
        var server = new Server
        {
            CPU = cpu,
            GPU = gpu,
            RAM = ram,
            Storage = storage,
            OS = os,
            PricePerHour = pricePerHour,
            PricePerDay = pricePerHour * DailyRateHours,
            IsActive = true,
            OperationalStatus = ServerOperationalStatus.Available,
            FinderEligible = true
        };

        ApplyDefaultMetadata(server);
        return server;
    }

    private static void ApplyDefaultMetadata(Server server)
    {
        var cpuLevel = GetCpuLevel(server.CPU);
        var (gpuLevel, training, inference, rendering) = GetGpuProfile(server.GPU);

        server.CpuCapabilityLevel = cpuLevel;
        server.GpuCapabilityLevel = gpuLevel;
        server.PerformanceTier = Math.Max(cpuLevel, gpuLevel) switch
        {
            >= 90 => ServerPerformanceTier.Extreme,
            >= 75 => ServerPerformanceTier.High,
            >= 55 => ServerPerformanceTier.Standard,
            _ => ServerPerformanceTier.Entry
        };

        server.WorkloadCapabilities.Clear();
        AddCapability(server, ServerWorkloadType.GeneralCompute, Math.Max(cpuLevel, gpuLevel));
        AddCapability(server, ServerWorkloadType.DevelopmentCompilation, cpuLevel);
        AddCapability(server, ServerWorkloadType.DataProcessing, Math.Max(cpuLevel, server.RAM.Contains("128") || server.RAM.Contains("256") ? 85 : 55));
        AddCapability(server, ServerWorkloadType.WebBackendHosting, cpuLevel);
        AddCapability(server, ServerWorkloadType.ModelTraining, training);
        AddCapability(server, ServerWorkloadType.Inference, inference);
        AddCapability(server, ServerWorkloadType.Rendering, rendering);
    }

    private static void AddCapability(Server server, ServerWorkloadType type, int score)
    {
        if (score < 20)
        {
            return;
        }

        server.WorkloadCapabilities.Add(new ServerWorkloadCapability
        {
            WorkloadType = type,
            SuitabilityLevel = (byte)Math.Clamp((int)Math.Ceiling(score / 20d), 1, 5)
        });
    }

    private static int GetCpuLevel(string cpu)
    {
        return cpu switch
        {
            var value when value.Contains("EPYC 9654", StringComparison.OrdinalIgnoreCase) => 100,
            var value when value.Contains("EPYC 7763", StringComparison.OrdinalIgnoreCase) => 92,
            var value when value.Contains("Ryzen 9 7950X", StringComparison.OrdinalIgnoreCase) => 86,
            var value when value.Contains("EPYC 7543", StringComparison.OrdinalIgnoreCase) => 84,
            var value when value.Contains("Core i9-13900K", StringComparison.OrdinalIgnoreCase) => 84,
            var value when value.Contains("EPYC 7513", StringComparison.OrdinalIgnoreCase) => 82,
            var value when value.Contains("Xeon Gold 6354", StringComparison.OrdinalIgnoreCase) => 82,
            var value when value.Contains("Xeon Gold 6330", StringComparison.OrdinalIgnoreCase) => 80,
            var value when value.Contains("Xeon Gold 6248R", StringComparison.OrdinalIgnoreCase) => 76,
            var value when value.Contains("EPYC 7302", StringComparison.OrdinalIgnoreCase) => 72,
            var value when value.Contains("Ryzen 7 7700X", StringComparison.OrdinalIgnoreCase) => 70,
            var value when value.Contains("Core i7-12700K", StringComparison.OrdinalIgnoreCase) => 68,
            var value when value.Contains("Xeon W-2295", StringComparison.OrdinalIgnoreCase) => 68,
            var value when value.Contains("Xeon Silver 4314", StringComparison.OrdinalIgnoreCase) => 62,
            _ => 55
        };
    }

    private static (int Gpu, int Training, int Inference, int Rendering) GetGpuProfile(string gpu)
    {
        return gpu switch
        {
            var value when value.Contains("H100", StringComparison.OrdinalIgnoreCase) => (100, 100, 100, 75),
            var value when value.Contains("A100", StringComparison.OrdinalIgnoreCase) => (94, 95, 92, 70),
            var value when value.Contains("L4", StringComparison.OrdinalIgnoreCase) => (86, 68, 95, 72),
            var value when value.Contains("RTX 4070", StringComparison.OrdinalIgnoreCase) => (84, 72, 82, 95),
            var value when value.Contains("RTX 3090", StringComparison.OrdinalIgnoreCase) => (83, 80, 78, 92),
            var value when value.Contains("A10", StringComparison.OrdinalIgnoreCase) => (82, 74, 86, 78),
            var value when value.Contains("V100", StringComparison.OrdinalIgnoreCase) => (78, 78, 72, 66),
            var value when value.Contains("RTX 3080", StringComparison.OrdinalIgnoreCase) => (76, 68, 68, 86),
            var value when value.Contains("T4", StringComparison.OrdinalIgnoreCase) => (65, 48, 76, 50),
            var value when value.Contains("RTX 3070", StringComparison.OrdinalIgnoreCase) => (64, 54, 58, 76),
            var value when value.Contains("RTX 3060", StringComparison.OrdinalIgnoreCase) => (62, 52, 60, 70),
            var value when value.Contains("GTX 1660", StringComparison.OrdinalIgnoreCase) => (45, 30, 38, 52),
            _ => (0, 0, 0, 0)
        };
    }
}
