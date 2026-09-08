namespace FinalMvcApp.DTOs.Reservations;

public class CreateReservationDto
{
    public int ServerId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal? QuotedTotalPrice { get; set; }
}
