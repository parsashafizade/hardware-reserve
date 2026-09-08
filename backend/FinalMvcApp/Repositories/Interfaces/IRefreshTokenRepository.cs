using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IRefreshTokenRepository
{
    Task AddAsync(RefreshToken refreshToken, CancellationToken cancellationToken = default);

    Task<RefreshToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RefreshToken>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default);

    void Update(RefreshToken refreshToken);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
