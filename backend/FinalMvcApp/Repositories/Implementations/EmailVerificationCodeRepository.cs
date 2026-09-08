using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class EmailVerificationCodeRepository
    : Repository<EmailVerificationCode>,
      IEmailVerificationCodeRepository
{
    public EmailVerificationCodeRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<EmailVerificationCode?> GetLatestByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code => code.UserId == userId)
            .OrderByDescending(code => code.CreatedAt)
            .ThenByDescending(code => code.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<EmailVerificationCode?> GetLatestUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code => code.UserId == userId && code.UsedAt == null)
            .OrderByDescending(code => code.CreatedAt)
            .ThenByDescending(code => code.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<EmailVerificationCode>> GetUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(code => code.UserId == userId && code.UsedAt == null)
            .OrderByDescending(code => code.CreatedAt)
            .ToListAsync(cancellationToken);
    }
}
