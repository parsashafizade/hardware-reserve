using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IUserRepository : IRepository<User>
{
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);

    Task<bool> EmailExistsAsync(string email, int? excludedUserId = null, CancellationToken cancellationToken = default);
}
