namespace FinalMvcApp.DTOs.Reservations;

public class ReservationQuoteResultDto
{
    public int ServerId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal DurationHours { get; set; }

    public decimal TotalPrice { get; set; }

    public string PricingMode { get; set; } = string.Empty;

    public bool IsAvailable { get; set; }
}
