namespace FinalMvcApp.DTOs.Reservations;

public class ServerSpecsDto
{
    public int ServerId { get; set; }

    public string CPU { get; set; } = string.Empty;

    public string GPU { get; set; } = string.Empty;

    public string RAM { get; set; } = string.Empty;

    public string Storage { get; set; } = string.Empty;

    public string OS { get; set; } = string.Empty;
}
