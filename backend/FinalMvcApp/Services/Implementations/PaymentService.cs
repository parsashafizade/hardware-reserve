using FinalMvcApp.DTOs.Payments;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;

namespace FinalMvcApp.Services.Implementations;

public class PaymentService : IPaymentService
{
    private readonly IReservationRepository _reservationRepository;
    private readonly IPaymentRepository _paymentRepository;
    private readonly IUserNotificationService _notificationService;

    public PaymentService(
        IReservationRepository reservationRepository,
        IPaymentRepository paymentRepository,
        IUserNotificationService notificationService)
    {
        _reservationRepository = reservationRepository;
        _paymentRepository = paymentRepository;
        _notificationService = notificationService;
    }

    public async Task<PaymentResultDto> PayReservationAsync(int userId, int reservationId, CancellationToken cancellationToken = default)
    {
        var reservation = await _reservationRepository.GetByIdAsync(reservationId, cancellationToken)
            ?? throw new KeyNotFoundException("Reservation not found.");

        if (reservation.UserId != userId)
        {
            throw new UnauthorizedAccessException("You can only pay your own reservation.");
        }

        var existingPayment = await _paymentRepository.GetByReservationIdAsync(
            reservationId,
            cancellationToken);

        // A client can lose the successful response after the transaction has
        // committed. Returning the completed payment makes an explicit retry
        // safe without creating another payment or notification.
        if (reservation.Status == ReservationStatus.Paid
            && existingPayment?.Status == PaymentStatus.Completed)
        {
            return ToResult(existingPayment);
        }

        if (reservation.Status != ReservationStatus.PendingPayment)
        {
            throw new InvalidOperationException("Reservation is not awaiting payment.");
        }

        if (existingPayment is not null)
        {
            throw new InvalidOperationException("This reservation is already paid.");
        }

        var payment = new Payment
        {
            ReservationId = reservation.Id,
            Amount = reservation.TotalPrice,
            Status = PaymentStatus.Completed,
            PaymentDate = DateTime.UtcNow
        };

        reservation.Status = ReservationStatus.Paid;
        _reservationRepository.Update(reservation);

        await _paymentRepository.AddAsync(payment, cancellationToken);
        await _paymentRepository.SaveChangesAsync(cancellationToken);

        await _notificationService.DispatchAsync(
            new UserNotificationRequest(
                userId,
                UserNotificationType.PaymentConfirmed,
                $"reservation:{reservation.Id}:payment-confirmed",
                ServerLabel.For(reservation.Server),
                reservation.Id,
                EventTime: payment.PaymentDate),
            CancellationToken.None);

        return ToResult(payment);
    }

    private static PaymentResultDto ToResult(Payment payment)
    {
        return new PaymentResultDto
        {
            PaymentId = payment.Id,
            ReservationId = payment.ReservationId,
            Amount = payment.Amount,
            PaymentDate = payment.PaymentDate,
            Status = payment.Status.ToString()
        };
    }
}
