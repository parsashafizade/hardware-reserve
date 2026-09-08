namespace FinalMvcApp.DTOs.Admin;

public class AssignCredentialsDto
{
    public int ReservationId { get; set; }

    public string AssignedIp { get; set; } = string.Empty;

    public string AssignedUsername { get; set; } = string.Empty;

    public string AssignedPassword { get; set; } = string.Empty;
}
