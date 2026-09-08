namespace FinalMvcApp.DTOs.Reservations;

public class ReservationSuggestionResultDto
{
    public DateTime? SuggestedStart { get; set; }

    public DateTime? SuggestedEnd { get; set; }

    public string Message { get; set; } = string.Empty;
}
