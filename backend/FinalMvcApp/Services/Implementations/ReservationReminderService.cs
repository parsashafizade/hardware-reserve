using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;

namespace FinalMvcApp.Services.Implementations;

public class ReservationReminderService : IReservationReminderService
{
    private static readonly TimeSpan StartReminderLead = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan EndReminderLead = TimeSpan.FromMinutes(10);
    private readonly IReservationRepository _reservationRepository;
    private readonly IUserNotificationService _notificationService;
    private readonly IServiceDetailsNotificationService _serviceDetailsNotificationService;

    public ReservationReminderService(
        IReservationRepository reservationRepository,
        IUserNotificationService notificationService,
        IServiceDetailsNotificationService serviceDetailsNotificationService)
    {
        _reservationRepository = reservationRepository;
        _notificationService = notificationService;
        _serviceDetailsNotificationService = serviceDetailsNotificationService;
    }

    public async Task ProcessDueAsync(DateTime nowUtc, CancellationToken cancellationToken = default)
    {
        nowUtc = NormalizeToUtc(nowUtc);
        await _serviceDetailsNotificationService.ProcessPendingAsync(cancellationToken);
        var reservations = await _reservationRepository.GetPaidForNotificationWindowAsync(
            nowUtc,
            nowUtc.Add(StartReminderLead),
            cancellationToken);

        foreach (var reservation in reservations)
        {
            var label = ServerLabel.For(reservation.Server);

            if (reservation.StartTime > nowUtc
                && reservation.StartTime <= nowUtc.Add(StartReminderLead))
            {
                await DispatchAsync(
                    reservation,
                    UserNotificationType.ReservationStartsSoon,
                    "starts-soon",
                    label,
                    reservation.StartTime,
                    cancellationToken);
                continue;
            }

            if (reservation.StartTime <= nowUtc
                && !reservation.StartedNotificationDelivered
                && await EnsureDurableAsync(
                    reservation,
                    UserNotificationType.ReservationStarted,
                    "started",
                    label,
                    reservation.StartTime,
                    cancellationToken))
            {
                await _reservationRepository.MarkStartedNotificationDeliveredAsync(
                    reservation.Id,
                    cancellationToken);
                reservation.StartedNotificationDelivered = true;
            }

            if (reservation.EndTime > nowUtc)
            {
                if (reservation.EndTime <= nowUtc.Add(EndReminderLead))
                {
                    await DispatchAsync(
                        reservation,
                        UserNotificationType.ReservationEndsSoon,
                        "ends-soon",
                        label,
                        reservation.EndTime,
                        cancellationToken);
                }

                continue;
            }

            if (!reservation.CompletedNotificationDelivered
                && await EnsureDurableAsync(
                    reservation,
                    UserNotificationType.ReservationCompleted,
                    "completed",
                    label,
                    reservation.EndTime,
                    cancellationToken))
            {
                await _reservationRepository.MarkCompletedNotificationDeliveredAsync(
                    reservation.Id,
                    cancellationToken);
                reservation.CompletedNotificationDelivered = true;
            }
        }
    }

    private async Task<bool> EnsureDurableAsync(
        Reservation reservation,
        UserNotificationType type,
        string eventKey,
        string label,
        DateTime eventTime,
        CancellationToken cancellationToken)
    {
        var deduplicationKey = $"reservation:{reservation.Id}:{eventKey}";
        var created = await _notificationService.DispatchAsync(
            new UserNotificationRequest(
                reservation.UserId,
                type,
                deduplicationKey,
                label,
                reservation.Id,
                EventTime: eventTime),
            cancellationToken);
        return created is not null
            || await _notificationService.ExistsAsync(
                reservation.UserId,
                deduplicationKey,
                cancellationToken);
    }

    private Task DispatchAsync(
        Reservation reservation,
        UserNotificationType type,
        string eventKey,
        string label,
        DateTime eventTime,
        CancellationToken cancellationToken)
    {
        return _notificationService.DispatchAsync(
            new UserNotificationRequest(
                reservation.UserId,
                type,
                $"reservation:{reservation.Id}:{eventKey}",
                label,
                reservation.Id,
                EventTime: eventTime),
            cancellationToken);
    }

    private static DateTime NormalizeToUtc(DateTime value)
    {
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
    }
}
