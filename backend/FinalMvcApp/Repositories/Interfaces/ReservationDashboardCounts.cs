namespace FinalMvcApp.Repositories.Interfaces;

public class ReservationDashboardCounts
{
    public int TotalReservations { get; set; }

    public int PendingPayment { get; set; }

    public int Active { get; set; }

    public int Upcoming { get; set; }

    public int Completed { get; set; }
}
