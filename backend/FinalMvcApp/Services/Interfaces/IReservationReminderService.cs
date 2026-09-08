namespace FinalMvcApp.Services.Interfaces;

public interface IReservationReminderService
{
    Task ProcessDueAsync(DateTime nowUtc, CancellationToken cancellationToken = default);
}
