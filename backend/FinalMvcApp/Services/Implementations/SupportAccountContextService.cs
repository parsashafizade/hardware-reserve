using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class SupportAccountContextService : ISupportAccountContextService
{
    private const int MaxReservations = 20;
    private const int MaxServers = 30;
    private readonly IReservationRepository _reservationRepository;
    private readonly IServerRepository _serverRepository;

    public SupportAccountContextService(
        IReservationRepository reservationRepository,
        IServerRepository serverRepository)
    {
        _reservationRepository = reservationRepository;
        _serverRepository = serverRepository;
    }

    public async Task<SupportAccountContext> GetContextAsync(
        int? authenticatedUserId,
        SupportAccountCapability capability,
        int? reservationId,
        CancellationToken cancellationToken = default)
    {
        if (capability == SupportAccountCapability.NONE)
        {
            return new SupportAccountContext { Capability = capability };
        }

        if (capability == SupportAccountCapability.PUBLIC_SERVERS)
        {
            var servers = await _serverRepository.GetActiveAsync(cancellationToken);
            return new SupportAccountContext
            {
                Capability = capability,
                AvailableServers = servers.Take(MaxServers).Select(MapServer).ToList()
            };
        }

        if (!authenticatedUserId.HasValue)
        {
            return new SupportAccountContext
            {
                Capability = capability,
                RequiresAuthentication = true
            };
        }

        if (reservationId.HasValue)
        {
            var ownedReservation = await _reservationRepository.GetByIdForUserAsync(
                reservationId.Value,
                authenticatedUserId.Value,
                cancellationToken);
            return new SupportAccountContext
            {
                Capability = capability,
                RequestedReservationNotFound = ownedReservation is null,
                Reservations = ownedReservation is null ? [] : [MapReservation(ownedReservation)]
            };
        }

        var paidOnly = capability is SupportAccountCapability.PAID_SERVICES
            or SupportAccountCapability.PROVISIONING_STATUS;
        var reservations = await _reservationRepository.GetRecentByUserIdAsync(
            authenticatedUserId.Value,
            MaxReservations,
            paidOnly,
            cancellationToken);

        return new SupportAccountContext
        {
            Capability = capability,
            Reservations = reservations.Select(MapReservation).ToList()
        };
    }

    private static SupportReservationContext MapReservation(Reservation reservation)
    {
        return new SupportReservationContext
        {
            ReservationId = reservation.Id,
            ReservationStatus = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            PaymentDate = reservation.Payment?.PaymentDate,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            CredentialsAssigned = !string.IsNullOrWhiteSpace(reservation.AssignedIp)
                && !string.IsNullOrWhiteSpace(reservation.AssignedUsername)
                && !string.IsNullOrWhiteSpace(reservation.AssignedPassword),
            Server = MapServer(reservation.Server)
        };
    }

    private static SupportServerContext MapServer(Server server)
    {
        return new SupportServerContext
        {
            ServerId = server.Id,
            CPU = server.CPU,
            GPU = server.GPU,
            RAM = server.RAM,
            Storage = server.Storage,
            OS = server.OS,
            PricePerHour = server.PricePerHour,
            PricePerDay = server.PricePerDay
        };
    }
}
