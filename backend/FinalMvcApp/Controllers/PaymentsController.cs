using FinalMvcApp.DTOs.Payments;
using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize]
[Route("payments")]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [HttpPost("{reservationId:int}")]
    public async Task<ActionResult<PaymentResultDto>> Pay(int reservationId, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var response = await _paymentService.PayReservationAsync(userId, reservationId, cancellationToken);
        return Ok(response);
    }
}
