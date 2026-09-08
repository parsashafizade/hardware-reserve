using FinalMvcApp.DTOs.Payments;

namespace FinalMvcApp.Services.Interfaces;

public interface IPaymentService
{
    Task<PaymentResultDto> PayReservationAsync(int userId, int reservationId, CancellationToken cancellationToken = default);
}
