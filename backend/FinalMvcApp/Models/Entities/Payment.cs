using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class Payment
{
    public int Id { get; set; }

    [Required]
    public int ReservationId { get; set; }

    [Range(typeof(decimal), "0.01", "9999999999999999.99")]
    public decimal Amount { get; set; }

    [Required]
    public DateTime PaymentDate { get; set; } = DateTime.UtcNow;

    [Required]
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    public Reservation Reservation { get; set; } = null!;
}
