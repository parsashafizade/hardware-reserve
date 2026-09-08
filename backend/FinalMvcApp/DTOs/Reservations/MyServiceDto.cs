namespace FinalMvcApp.DTOs.Reservations;

public class MyServiceDto
{
    public int ReservationId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal TotalPrice { get; set; }

    public ServerSpecsDto Server { get; set; } = new();

    public string? AssignedIp { get; set; }

    public string? AssignedUsername { get; set; }

    public string? AssignedPassword { get; set; }

    public string? Message { get; set; }
}
