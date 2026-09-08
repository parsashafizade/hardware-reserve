using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface ISupportQuickReplyRepository
{
    Task AddAsync(SupportQuickReply quickReply, CancellationToken cancellationToken = default);

    Task<SupportQuickReply?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SupportQuickReply>> GetAllAsync(
        bool includeInactive,
        CancellationToken cancellationToken = default);

    void Update(SupportQuickReply quickReply);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
