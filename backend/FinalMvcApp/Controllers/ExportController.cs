using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize]
[Route("export")]
public class ExportController : ControllerBase
{
    private readonly IReservationService _reservationService;

    public ExportController(IReservationService reservationService)
    {
        _reservationService = reservationService;
    }

    [HttpGet("csv")]
    public async Task<IActionResult> ExportCsv(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var file = await _reservationService.ExportMyReservationsCsvAsync(userId, cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }
}
