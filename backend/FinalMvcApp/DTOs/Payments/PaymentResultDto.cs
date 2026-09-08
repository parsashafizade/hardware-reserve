namespace FinalMvcApp.DTOs.Payments;

public class PaymentResultDto
{
    public int PaymentId { get; set; }

    public int ReservationId { get; set; }

    public decimal Amount { get; set; }

    public DateTime PaymentDate { get; set; }

    public string Status { get; set; } = string.Empty;
}
