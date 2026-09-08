using FinalMvcApp.DTOs.Reservations;

namespace FinalMvcApp.DTOs.Dashboard;

public class DashboardSummaryDto
{
    public DateTime ServerTimeUtc { get; set; }

    public string PrimaryState { get; set; } = DashboardPrimaryStates.Discovery;

    public DashboardReservationDto? PrimaryReservation { get; set; }

    public DashboardMetricsDto Metrics { get; set; } = new();
}

public class DashboardReservationDto
{
    public int ReservationId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public decimal TotalPrice { get; set; }

    public string Status { get; set; } = string.Empty;

    public string PaymentStatus { get; set; } = "Unpaid";

    public bool CanReserveAgain { get; set; }

    public ServerSpecsDto Server { get; set; } = new();
}

public class DashboardMetricsDto
{
    public int TotalReservations { get; set; }

    public int PendingPayment { get; set; }

    public int Active { get; set; }

    public int Upcoming { get; set; }

    public int Completed { get; set; }
}

public static class DashboardPrimaryStates
{
    public const string PendingPayment = "PENDING_PAYMENT";
    public const string Active = "ACTIVE";
    public const string StartingSoon = "STARTING_SOON";
    public const string Upcoming = "UPCOMING";
    public const string RecentCompleted = "RECENT_COMPLETED";
    public const string Discovery = "DISCOVERY";
}
