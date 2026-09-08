using FinalMvcApp.DTOs.Export;
using FinalMvcApp.DTOs.Reservations;

namespace FinalMvcApp.Services.Interfaces;

public interface IReservationService
{
    Task<CreateReservationResultDto> CreateAsync(int userId, CreateReservationDto dto, CancellationToken cancellationToken = default);

    Task<ReservationQuoteResultDto> QuoteAsync(
        CreateReservationDto dto,
        CancellationToken cancellationToken = default);

    Task<ReservationSuggestionResultDto> SuggestAsync(ReservationSuggestionRequestDto request, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ReservationBusySlotDto>> GetBusySlotsAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<MyReservationDto>> GetMyReservationsAsync(int userId, CancellationToken cancellationToken = default);

    Task<MyReservationDto> GetMyReservationByIdAsync(int userId, int reservationId, CancellationToken cancellationToken = default);

    Task<ReservationCockpitDto> GetCockpitAsync(
        int userId,
        int reservationId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<MyServiceDto>> GetMyServicesAsync(int userId, CancellationToken cancellationToken = default);

    Task<FileResultDto> ExportMyReservationsCsvAsync(int userId, CancellationToken cancellationToken = default);
}
