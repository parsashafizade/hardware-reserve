using FinalMvcApp.Services.AI;

namespace FinalMvcApp.Services.Interfaces;

public interface ISupportAccountContextService
{
    Task<SupportAccountContext> GetContextAsync(
        int? authenticatedUserId,
        SupportAccountCapability capability,
        int? reservationId,
        CancellationToken cancellationToken = default);
}
