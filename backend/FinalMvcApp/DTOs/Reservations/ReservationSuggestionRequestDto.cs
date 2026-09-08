namespace FinalMvcApp.DTOs.Reservations;

public class ReservationSuggestionRequestDto
{
    public int ServerId { get; set; }

    public decimal DesiredDurationHours { get; set; }
}
