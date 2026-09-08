using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IPendingEmailChangeRepository
    : IRepository<PendingEmailChange>
{
    Task<PendingEmailChange?> GetByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default);
}
