namespace FinalMvcApp.DTOs.Dashboard;

public class CommandSearchQueryDto
{
    public string Query { get; set; } = string.Empty;

    public int Limit { get; set; } = 4;
}

public class CommandSearchResultDto
{
    public IReadOnlyList<CommandServerResultDto> Servers { get; set; } = [];

    public IReadOnlyList<CommandReservationResultDto> Reservations { get; set; } = [];
}

public class CommandServerResultDto
{
    public int ServerId { get; set; }

    public string Label { get; set; } = string.Empty;

    public string CPU { get; set; } = string.Empty;

    public string GPU { get; set; } = string.Empty;

    public string RAM { get; set; } = string.Empty;

    public decimal PricePerHour { get; set; }
}

public class CommandReservationResultDto
{
    public int ReservationId { get; set; }

    public int ServerId { get; set; }

    public string ServerLabel { get; set; } = string.Empty;

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public string Status { get; set; } = string.Empty;

    public string PaymentStatus { get; set; } = "Unpaid";
}
