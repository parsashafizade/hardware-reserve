using FinalMvcApp.Data;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Tests;

internal static class TestDbFactory
{
    public static ApplicationDbContext Create()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new ApplicationDbContext(options);
    }
}
