using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IEmailVerificationCodeRepository : IRepository<EmailVerificationCode>
{
    Task<EmailVerificationCode?> GetLatestByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<EmailVerificationCode?> GetLatestUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<EmailVerificationCode>> GetUnusedByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);
}
