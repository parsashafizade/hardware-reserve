namespace FinalMvcApp.DTOs.Admin;

public class DashboardStatsDto
{
    public int TotalUsers { get; set; }

    public int TotalServers { get; set; }

    public int TotalPurchases { get; set; }

    public int ActiveReservations { get; set; }

    public int UpcomingReservations { get; set; }

    public int StartingSoonReservations { get; set; }

    public int EndingSoonReservations { get; set; }

    public int PendingPayments { get; set; }

    public int UnavailableServers { get; set; }

    public int MaintenanceServers { get; set; }

    public int WaitingSupportConversations { get; set; }

    public int PendingAssignmentReservations { get; set; }

    public int SupportAttentionConversations { get; set; }

    public IReadOnlyList<AdminAuditEventDto> RecentAuditEvents { get; set; } = [];
}
