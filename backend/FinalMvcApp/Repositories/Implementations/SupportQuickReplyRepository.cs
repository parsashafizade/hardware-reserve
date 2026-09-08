using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class SupportQuickReplyRepository : ISupportQuickReplyRepository
{
    private readonly ApplicationDbContext _context;

    public SupportQuickReplyRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task AddAsync(SupportQuickReply quickReply, CancellationToken cancellationToken = default)
    {
        await _context.SupportQuickReplies.AddAsync(quickReply, cancellationToken);
    }

    public async Task<SupportQuickReply?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.SupportQuickReplies.FirstOrDefaultAsync(quickReply => quickReply.Id == id, cancellationToken);
    }

    public async Task<IReadOnlyList<SupportQuickReply>> GetAllAsync(
        bool includeInactive,
        CancellationToken cancellationToken = default)
    {
        var query = _context.SupportQuickReplies.AsNoTracking();

        if (!includeInactive)
        {
            query = query.Where(quickReply => quickReply.IsActive);
        }

        return await query
            .OrderBy(quickReply => quickReply.SortOrder)
            .ThenBy(quickReply => quickReply.Title)
            .ToListAsync(cancellationToken);
    }

    public void Update(SupportQuickReply quickReply)
    {
        _context.SupportQuickReplies.Update(quickReply);
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}
