namespace FinalMvcApp.DTOs.Admin;

public class AdminReservationDetailDto : AdminOrderDto
{
    public string? AssignedIp { get; set; }

    public string? AssignedUsername { get; set; }

    public string? AssignedPassword { get; set; }
}
