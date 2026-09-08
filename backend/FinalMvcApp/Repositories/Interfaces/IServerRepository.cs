using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IServerRepository : IRepository<Server>
{
    Task<IReadOnlyList<Server>> GetActiveAsync(CancellationToken cancellationToken = default);

    Task<Server?> GetActiveByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Server>> FilterActiveAsync(
        string? cpu,
        string? gpu,
        string? ram,
        string? storage,
        string? os,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Server>> SearchActiveAsync(
        string normalizedQuery,
        int? serverId,
        int take,
        CancellationToken cancellationToken = default);
}
