namespace FinalMvcApp.DTOs.Reservations;

public class MyReservationDto
{
    public int ReservationId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal TotalPrice { get; set; }

    public string Status { get; set; } = string.Empty;

    public string PaymentStatus { get; set; } = "Unpaid";

    public ServerSpecsDto Server { get; set; } = new();
}
