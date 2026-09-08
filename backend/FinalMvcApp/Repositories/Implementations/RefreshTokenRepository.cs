using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly ApplicationDbContext _context;

    public RefreshTokenRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default)
    {
        await _context.RefreshTokens.AddAsync(refreshToken, cancellationToken);
    }

    public async Task<RefreshToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default)
    {
        return await _context.RefreshTokens
            .Include(refreshToken => refreshToken.User)
            .FirstOrDefaultAsync(refreshToken => refreshToken.Token == token, cancellationToken);
    }

    public async Task<IReadOnlyList<RefreshToken>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default)
    {
        return await _context.RefreshTokens
            .Where(refreshToken => refreshToken.UserId == userId)
            .OrderByDescending(refreshToken => refreshToken.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public void Update(RefreshToken refreshToken)
    {
        _context.RefreshTokens.Update(refreshToken);
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}
