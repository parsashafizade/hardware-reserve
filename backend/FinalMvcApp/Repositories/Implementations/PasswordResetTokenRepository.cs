using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class PasswordResetTokenRepository : Repository<PasswordResetToken>, IPasswordResetTokenRepository
{
    public PasswordResetTokenRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<PasswordResetToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(passwordResetToken => passwordResetToken.User)
            .FirstOrDefaultAsync(passwordResetToken => passwordResetToken.Token == token, cancellationToken);
    }

    public async Task<IReadOnlyList<PasswordResetToken>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(passwordResetToken => passwordResetToken.UserId == userId)
            .ToListAsync(cancellationToken);
    }
}
