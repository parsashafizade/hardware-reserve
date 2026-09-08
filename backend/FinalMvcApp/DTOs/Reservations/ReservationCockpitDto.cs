namespace FinalMvcApp.DTOs.Reservations;

public class ReservationCockpitDto : MyReservationDto
{
    public DateTime ServerTimeUtc { get; set; }

    public int? PaymentId { get; set; }

    public DateTime? PaymentDate { get; set; }

    public string? AssignedIp { get; set; }

    public string? AssignedUsername { get; set; }

    public string? AssignedPassword { get; set; }
}
