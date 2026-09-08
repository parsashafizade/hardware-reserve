using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Repositories.Interfaces;

public interface IPaymentRepository : IRepository<Payment>
{
    Task<Payment?> GetByReservationIdAsync(int reservationId, CancellationToken cancellationToken = default);
}
