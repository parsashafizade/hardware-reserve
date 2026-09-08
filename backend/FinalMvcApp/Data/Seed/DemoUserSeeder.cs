using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Data.Seed;

public static class DemoUserSeeder
{
    public static async Task SeedAsync(ApplicationDbContext dbContext, CancellationToken cancellationToken = default)
    {
        const string demoEmail = "demo@university.local";

        var demoUser = await dbContext.Users.FirstOrDefaultAsync(
            user => user.Email == demoEmail,
            cancellationToken);

        if (demoUser is not null)
        {
            if (!demoUser.IsEmailVerified
                || demoUser.EmailVerifiedAt is null)
            {
                demoUser.IsEmailVerified = true;
                demoUser.EmailVerifiedAt = DateTime.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }

            return;
        }

        demoUser = new User
        {
            FullName = "Demo Student",
            Email = demoEmail,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("1234"),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = true,
            EmailVerifiedAt = DateTime.UtcNow
        };

        await dbContext.Users.AddAsync(demoUser, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
