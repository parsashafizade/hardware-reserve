using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;

namespace FinalMvcApp.Services.Implementations;

public class ServiceDetailsNotificationService : IServiceDetailsNotificationService
{
    private const int ReconciliationBatchSize = 100;
    private readonly IReservationRepository _reservationRepository;
    private readonly IUserNotificationService _notificationService;
    private readonly TimeProvider _timeProvider;
    private readonly ILogger<ServiceDetailsNotificationService> _logger;

    public ServiceDetailsNotificationService(
        IReservationRepository reservationRepository,
        IUserNotificationService notificationService,
        TimeProvider timeProvider,
        ILogger<ServiceDetailsNotificationService> logger)
    {
        _reservationRepository = reservationRepository;
        _notificationService = notificationService;
        _timeProvider = timeProvider;
        _logger = logger;
    }

    public async Task<bool> EnsureDeliveredAsync(
        Reservation reservation,
        int serviceDetailsVersion,
        CancellationToken cancellationToken = default)
    {
        if (serviceDetailsVersion <= 0)
        {
            return false;
        }

        var deduplicationKey = GetDeduplicationKey(reservation.Id, serviceDetailsVersion);
        try
        {
            var created = await _notificationService.DispatchAsync(
                new UserNotificationRequest(
                    reservation.UserId,
                    UserNotificationType.ServiceDetailsAssigned,
                    deduplicationKey,
                    ServerLabel.For(reservation.Server),
                    reservation.Id,
                    EventTime: _timeProvider.GetUtcNow().UtcDateTime),
                cancellationToken);
            var isDurable = created is not null
                || await _notificationService.ExistsAsync(
                    reservation.UserId,
                    deduplicationKey,
                    cancellationToken);
            if (!isDurable)
            {
                return false;
            }

            await _reservationRepository.MarkServiceDetailsNotificationDeliveredAsync(
                reservation.Id,
                serviceDetailsVersion,
                cancellationToken);
            return true;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // The persisted version remains pending and the background worker retries it.
            _logger.LogError(
                exception,
                "Could not reconcile service-details notification for reservation {ReservationId} version {ServiceDetailsVersion}",
                reservation.Id,
                serviceDetailsVersion);
            return false;
        }
    }

    public async Task ProcessPendingAsync(CancellationToken cancellationToken = default)
    {
        var reservations = await _reservationRepository.GetPendingServiceDetailsNotificationsAsync(
            ReconciliationBatchSize,
            cancellationToken);
        foreach (var reservation in reservations)
        {
            await EnsureDeliveredAsync(
                reservation,
                reservation.ServiceDetailsVersion,
                cancellationToken);
        }
    }

    private static string GetDeduplicationKey(int reservationId, int version) =>
        $"reservation:{reservationId}:service-details:v{version}";
}
