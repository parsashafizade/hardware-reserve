using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IPasswordResetTokenRepository : IRepository<PasswordResetToken>
{
    Task<PasswordResetToken?> GetByTokenAsync(string token, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PasswordResetToken>> GetByUserIdAsync(int userId, CancellationToken cancellationToken = default);
}
