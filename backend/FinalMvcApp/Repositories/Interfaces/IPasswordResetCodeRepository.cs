using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IPasswordResetCodeRepository
    : IRepository<PasswordResetCode>
{
    Task<PasswordResetCode?> GetLatestByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<PasswordResetCode?> GetLatestUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PasswordResetCode>> GetUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);
}
