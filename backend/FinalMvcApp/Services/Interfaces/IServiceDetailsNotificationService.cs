using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Services.Interfaces;

public interface IServiceDetailsNotificationService
{
    Task<bool> EnsureDeliveredAsync(
        Reservation reservation,
        int serviceDetailsVersion,
        CancellationToken cancellationToken = default);

    Task ProcessPendingAsync(CancellationToken cancellationToken = default);
}
