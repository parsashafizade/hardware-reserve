namespace FinalMvcApp.DTOs.Reservations;

public class CreateReservationResultDto
{
    public int ReservationId { get; set; }

    public decimal TotalPrice { get; set; }

    public string DurationSummary { get; set; } = string.Empty;
}
