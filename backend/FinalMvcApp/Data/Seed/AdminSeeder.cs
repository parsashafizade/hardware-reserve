using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Data.Seed;

public static class AdminSeeder
{
    public static async Task SeedAsync(ApplicationDbContext dbContext, CancellationToken cancellationToken = default)
    {
        var adminUser = await dbContext.Users.FirstOrDefaultAsync(
            user => user.Role == UserRole.Admin,
            cancellationToken);

        if (adminUser is not null)
        {
            if (!adminUser.IsEmailVerified
                || adminUser.EmailVerifiedAt is null)
            {
                adminUser.IsEmailVerified = true;
                adminUser.EmailVerifiedAt = DateTime.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }

            return;
        }

        adminUser = new User
        {
            FullName = "System Admin",
            Email = "admin",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("1234"),
            Role = UserRole.Admin,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = true,
            EmailVerifiedAt = DateTime.UtcNow
        };

        await dbContext.Users.AddAsync(adminUser, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
