using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize]
[Route("reservations")]
public class ReservationsController : ControllerBase
{
    private readonly IReservationService _reservationService;

    public ReservationsController(IReservationService reservationService)
    {
        _reservationService = reservationService;
    }

    [HttpPost]
    public async Task<ActionResult<CreateReservationResultDto>> Create(CreateReservationDto request, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _reservationService.CreateAsync(userId, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("quote")]
    public async Task<ActionResult<ReservationQuoteResultDto>> Quote(
        CreateReservationDto request,
        CancellationToken cancellationToken)
    {
        var response = await _reservationService.QuoteAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("suggest")]
    public async Task<ActionResult<ReservationSuggestionResultDto>> Suggest(
        ReservationSuggestionRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _reservationService.SuggestAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("server/{serverId:int}/busy")]
    public async Task<ActionResult<IReadOnlyList<ReservationBusySlotDto>>> GetBusySlots(
        int serverId,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        CancellationToken cancellationToken)
    {
        var from = fromUtc ?? DateTime.UtcNow;
        var to = toUtc ?? DateTime.UtcNow.AddDays(14);
        var response = await _reservationService.GetBusySlotsAsync(serverId, from, to, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{reservationId:int}")]
    public async Task<ActionResult<MyReservationDto>> GetById(int reservationId, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _reservationService.GetMyReservationByIdAsync(userId, reservationId, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{reservationId:int}/cockpit")]
    public async Task<ActionResult<ReservationCockpitDto>> GetCockpit(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var response = await _reservationService.GetCockpitAsync(
            User.GetUserId(),
            reservationId,
            cancellationToken);
        return Ok(response);
    }
}
