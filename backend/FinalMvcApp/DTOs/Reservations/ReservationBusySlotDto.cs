namespace FinalMvcApp.DTOs.Reservations;

public class ReservationBusySlotDto
{
    public int? ReservationId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public string Source { get; set; } = "Reservation";
}
