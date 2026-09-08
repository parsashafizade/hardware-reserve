using FinalMvcApp.Data;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Repositories.Implementations;

public class PaymentRepository : Repository<Payment>, IPaymentRepository
{
    public PaymentRepository(ApplicationDbContext context)
        : base(context)
    {
    }

    public async Task<Payment?> GetByReservationIdAsync(int reservationId, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Include(payment => payment.Reservation)
            .FirstOrDefaultAsync(payment => payment.ReservationId == reservationId, cancellationToken);
    }
}
