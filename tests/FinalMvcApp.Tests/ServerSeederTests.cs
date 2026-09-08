using FinalMvcApp.Data.Seed;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Tests;

public class ServerSeederTests
{
    [Fact]
    public async Task SeedAsync_CreatesFifteenActiveServersWithConsistentDailyPricing()
    {
        await using var dbContext = TestDbFactory.Create();

        await ServerSeeder.SeedAsync(dbContext);

        var servers = await dbContext.Servers.ToListAsync();
        Assert.Equal(15, servers.Count);
        Assert.All(servers, server =>
        {
            Assert.True(server.IsActive);
            Assert.Equal(server.PricePerHour * 18m, server.PricePerDay);
        });

        var entryCpu = Assert.Single(servers, server => server.CPU == "AMD EPYC 7302");
        Assert.Equal(12_000m, entryCpu.PricePerHour);
        Assert.Equal(216_000m, entryCpu.PricePerDay);

        var h100 = Assert.Single(servers, server => server.GPU == "NVIDIA H100 80GB");
        Assert.Equal(520_000m, h100.PricePerHour);
        Assert.Equal(9_360_000m, h100.PricePerDay);
    }

    [Fact]
    public async Task SeedAsync_WhenRunAgain_RefreshesPricesWithoutCreatingDuplicates()
    {
        await using var dbContext = TestDbFactory.Create();
        await ServerSeeder.SeedAsync(dbContext);

        var h100 = await dbContext.Servers.SingleAsync(server => server.GPU == "NVIDIA H100 80GB");
        h100.PricePerHour = 1m;
        h100.PricePerDay = 1m;
        await dbContext.SaveChangesAsync();

        await ServerSeeder.SeedAsync(dbContext);

        Assert.Equal(15, await dbContext.Servers.CountAsync());
        h100 = await dbContext.Servers.SingleAsync(server => server.GPU == "NVIDIA H100 80GB");
        Assert.Equal(520_000m, h100.PricePerHour);
        Assert.Equal(9_360_000m, h100.PricePerDay);
    }
}
