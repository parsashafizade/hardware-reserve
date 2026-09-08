using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize]
[Route("")]
public class MyReservationsController : ControllerBase
{
    private readonly IReservationService _reservationService;

    public MyReservationsController(IReservationService reservationService)
    {
        _reservationService = reservationService;
    }

    [HttpGet("my-reservations")]
    public async Task<ActionResult<IReadOnlyList<MyReservationDto>>> GetMyReservations(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _reservationService.GetMyReservationsAsync(userId, cancellationToken);
        return Ok(response);
    }

    [HttpGet("my-services")]
    public async Task<ActionResult<IReadOnlyList<MyServiceDto>>> GetMyServices(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _reservationService.GetMyServicesAsync(userId, cancellationToken);
        return Ok(response);
    }
}
