using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class PasswordResetCodeRepository
    : Repository<PasswordResetCode>,
      IPasswordResetCodeRepository
{
    public PasswordResetCodeRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<PasswordResetCode?> GetLatestByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code => code.UserId == userId)
            .OrderByDescending(code => code.CreatedAt)
            .ThenByDescending(code => code.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<PasswordResetCode?> GetLatestUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code =>
                code.UserId == userId &&
                code.UsedAt == null)
            .OrderByDescending(code => code.CreatedAt)
            .ThenByDescending(code => code.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<PasswordResetCode>> GetUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code =>
                code.UserId == userId &&
                code.UsedAt == null)
            .ToListAsync(cancellationToken);
    }
}