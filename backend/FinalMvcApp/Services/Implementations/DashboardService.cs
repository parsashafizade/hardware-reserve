using System.Text.RegularExpressions;
using FinalMvcApp.DTOs.Dashboard;
using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;

namespace FinalMvcApp.Services.Implementations;

public partial class DashboardService : IDashboardService
{
    private static readonly TimeSpan StartingSoonWindow = TimeSpan.FromMinutes(30);
    private readonly IReservationRepository _reservationRepository;
    private readonly IServerRepository _serverRepository;
    private readonly TimeProvider _timeProvider;

    public DashboardService(
        IReservationRepository reservationRepository,
        IServerRepository serverRepository,
        TimeProvider timeProvider)
    {
        _reservationRepository = reservationRepository;
        _serverRepository = serverRepository;
        _timeProvider = timeProvider;
    }

    public async Task<DashboardSummaryDto> GetSummaryAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var primary = await _reservationRepository.GetDashboardPrimaryAsync(
            userId,
            nowUtc,
            cancellationToken);
        var counts = await _reservationRepository.GetDashboardCountsAsync(
            userId,
            nowUtc,
            cancellationToken);
        return new DashboardSummaryDto
        {
            ServerTimeUtc = nowUtc,
            PrimaryState = GetPrimaryState(primary, nowUtc),
            PrimaryReservation = primary is null ? null : MapReservation(primary),
            Metrics = new DashboardMetricsDto
            {
                TotalReservations = counts.TotalReservations,
                PendingPayment = counts.PendingPayment,
                Active = counts.Active,
                Upcoming = counts.Upcoming,
                Completed = counts.Completed
            }
        };
    }

    public async Task<CommandSearchResultDto> SearchCommandsAsync(
        int userId,
        CommandSearchQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var normalized = query.Query.Trim().ToLowerInvariant();
        var numericId = ParseResourceId(normalized);
        var status = ParseReservationStatus(normalized);
        var servers = await _serverRepository.SearchActiveAsync(
            normalized,
            numericId,
            query.Limit,
            cancellationToken);
        var reservations = await _reservationRepository.SearchForUserAsync(
            userId,
            normalized,
            numericId,
            status,
            query.Limit,
            cancellationToken);

        return new CommandSearchResultDto
        {
            Servers = servers
                .Select(server => new CommandServerResultDto
                {
                    ServerId = server.Id,
                    Label = ServerLabel.For(server),
                    CPU = server.CPU,
                    GPU = server.GPU,
                    RAM = server.RAM,
                    PricePerHour = server.PricePerHour
                })
                .ToList(),
            Reservations = reservations
                .Select(reservation => new CommandReservationResultDto
                {
                    ReservationId = reservation.Id,
                    ServerId = reservation.ServerId,
                    ServerLabel = ServerLabel.For(reservation.Server),
                    StartTime = reservation.StartTime,
                    EndTime = reservation.EndTime,
                    Status = reservation.Status.ToString(),
                    PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid"
                })
                .ToList()
        };
    }

    private static string GetPrimaryState(Reservation? reservation, DateTime nowUtc)
    {
        if (reservation is null)
        {
            return DashboardPrimaryStates.Discovery;
        }
        if (reservation.Status == ReservationStatus.PendingPayment)
        {
            return DashboardPrimaryStates.PendingPayment;
        }
        if (reservation.StartTime <= nowUtc && reservation.EndTime > nowUtc)
        {
            return DashboardPrimaryStates.Active;
        }
        if (reservation.StartTime > nowUtc)
        {
            return reservation.StartTime - nowUtc <= StartingSoonWindow
                ? DashboardPrimaryStates.StartingSoon
                : DashboardPrimaryStates.Upcoming;
        }
        return DashboardPrimaryStates.RecentCompleted;
    }

    private static DashboardReservationDto MapReservation(Reservation reservation)
    {
        return new DashboardReservationDto
        {
            ReservationId = reservation.Id,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            Status = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            CanReserveAgain = reservation.Server.IsActive,
            Server = new ServerSpecsDto
            {
                ServerId = reservation.ServerId,
                CPU = reservation.Server.CPU,
                GPU = reservation.Server.GPU,
                RAM = reservation.Server.RAM,
                Storage = reservation.Server.Storage,
                OS = reservation.Server.OS
            }
        };
    }

    private static int? ParseResourceId(string query)
    {
        var match = ResourceIdRegex().Match(query);
        return match.Success && int.TryParse(match.Value, out var value)
            ? value
            : null;
    }

    private static ReservationStatus? ParseReservationStatus(string query)
    {
        if (query.Contains("pending", StringComparison.Ordinal)
            || query.Contains("awaiting payment", StringComparison.Ordinal)
            || query.Contains("در انتظار پرداخت", StringComparison.Ordinal))
        {
            return ReservationStatus.PendingPayment;
        }
        if (query.Contains("cancel", StringComparison.Ordinal)
            || query.Contains("لغو", StringComparison.Ordinal))
        {
            return ReservationStatus.Cancelled;
        }
        if (query.Contains("paid", StringComparison.Ordinal)
            || query.Contains("پرداخت شده", StringComparison.Ordinal)
            || query.Contains("پرداخت‌شده", StringComparison.Ordinal))
        {
            return ReservationStatus.Paid;
        }
        return null;
    }

    [GeneratedRegex(@"\d+", RegexOptions.CultureInvariant)]
    private static partial Regex ResourceIdRegex();
}
