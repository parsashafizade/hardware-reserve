using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class ServerRepository : Repository<Server>, IServerRepository
{
    public ServerRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public override Task<Server?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return DbSet
            .Include(server => server.WorkloadCapabilities)
            .FirstOrDefaultAsync(server => server.Id == id, cancellationToken);
    }

    public override async Task<IReadOnlyList<Server>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(server => server.WorkloadCapabilities)
            .OrderByDescending(server => server.Id)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Server>> GetActiveAsync(CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(server => server.WorkloadCapabilities)
            .Where(server => server.IsActive)
            .OrderBy(server => server.PricePerHour)
            .ThenBy(server => server.Id)
            .ToListAsync(cancellationToken);
    }

    public async Task<Server?> GetActiveByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(server => server.WorkloadCapabilities)
            .FirstOrDefaultAsync(server => server.Id == id && server.IsActive, cancellationToken);
    }

    public async Task<IReadOnlyList<Server>> FilterActiveAsync(
        string? cpu,
        string? gpu,
        string? ram,
        string? storage,
        string? os,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet
            .Include(server => server.WorkloadCapabilities)
            .Where(server => server.IsActive);

        if (!string.IsNullOrWhiteSpace(cpu))
        {
            var normalized = cpu.Trim().ToLowerInvariant();
            query = query.Where(server => server.CPU.ToLower().Contains(normalized));
        }

        if (!string.IsNullOrWhiteSpace(gpu))
        {
            var normalized = gpu.Trim().ToLowerInvariant();
            query = query.Where(server => server.GPU.ToLower().Contains(normalized));
        }

        if (!string.IsNullOrWhiteSpace(ram))
        {
            var normalized = ram.Trim().ToLowerInvariant();
            query = query.Where(server => server.RAM.ToLower().Contains(normalized));
        }

        if (!string.IsNullOrWhiteSpace(storage))
        {
            var normalized = storage.Trim().ToLowerInvariant();
            query = query.Where(server => server.Storage.ToLower().Contains(normalized));
        }

        if (!string.IsNullOrWhiteSpace(os))
        {
            var normalized = os.Trim().ToLowerInvariant();
            query = query.Where(server => server.OS.ToLower().Contains(normalized));
        }

        return await query
            .OrderBy(server => server.PricePerHour)
            .ThenBy(server => server.Id)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Server>> SearchActiveAsync(
        string normalizedQuery,
        int? serverId,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(server => server.WorkloadCapabilities)
            .Where(server => server.IsActive
                && ((serverId.HasValue && server.Id == serverId.Value)
                    || server.CPU.ToLower().Contains(normalizedQuery)
                    || server.GPU.ToLower().Contains(normalizedQuery)
                    || server.RAM.ToLower().Contains(normalizedQuery)
                    || server.Storage.ToLower().Contains(normalizedQuery)
                    || server.OS.ToLower().Contains(normalizedQuery)))
            .OrderBy(server => serverId.HasValue && server.Id == serverId.Value ? 0 : 1)
            .ThenBy(server => server.PricePerHour)
            .ThenBy(server => server.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
}
