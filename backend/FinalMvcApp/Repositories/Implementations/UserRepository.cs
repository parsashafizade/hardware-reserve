using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class UserRepository : Repository<User>, IUserRepository
{
    public UserRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        return await DbSet.FirstOrDefaultAsync(user => user.Email == email, cancellationToken);
    }

    public async Task<bool> EmailExistsAsync(string email, int? excludedUserId = null, CancellationToken cancellationToken = default)
    {
        return await DbSet.AnyAsync(
            user => user.Email == email
                && (!excludedUserId.HasValue || user.Id != excludedUserId.Value),
            cancellationToken);
    }
}
