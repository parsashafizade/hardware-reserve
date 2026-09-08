using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class PendingEmailChangeRepository
    : Repository<PendingEmailChange>,
      IPendingEmailChangeRepository
{
    public PendingEmailChangeRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<PendingEmailChange?> GetByUserIdAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return await DbSet.FirstOrDefaultAsync(
            change => change.UserId == userId,
            cancellationToken);
    }
}
