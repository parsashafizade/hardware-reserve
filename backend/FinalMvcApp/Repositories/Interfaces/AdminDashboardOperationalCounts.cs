namespace FinalMvcApp.Repositories.Interfaces;

public sealed record AdminDashboardOperationalCounts(
    int ActiveReservations,
    int UpcomingReservations,
    int StartingSoonReservations,
    int EndingSoonReservations,
    int PendingPayments,
    int UnavailableServers,
    int MaintenanceServers,
    int WaitingSupportConversations,
    int PendingAssignmentReservations,
    int SupportAttentionConversations);
