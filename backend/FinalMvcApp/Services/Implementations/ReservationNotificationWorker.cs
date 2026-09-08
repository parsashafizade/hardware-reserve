using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class ReservationNotificationWorker : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(1);
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly TimeProvider _timeProvider;
    private readonly ILogger<ReservationNotificationWorker> _logger;

    public ReservationNotificationWorker(
        IServiceScopeFactory scopeFactory,
        TimeProvider timeProvider,
        ILogger<ReservationNotificationWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _timeProvider = timeProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(PollInterval, _timeProvider);

        do
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var reminderService = scope.ServiceProvider.GetRequiredService<IReservationReminderService>();
                await reminderService.ProcessDueAsync(
                    _timeProvider.GetUtcNow().UtcDateTime,
                    stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Reservation notification processing failed.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
