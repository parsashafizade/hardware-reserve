namespace FinalMvcApp.DTOs.Admin;

public class AdminUserOverviewDto
{
    public int Id { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Role { get; set; } = string.Empty;

    public bool IsEmailVerified { get; set; }

    public DateTime? EmailVerifiedAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public int ReservationCount { get; set; }

    public int ActiveReservationCount { get; set; }

    public int CompletedPaymentCount { get; set; }

    public int SupportConversationCount { get; set; }

    public int UnreadNotificationCount { get; set; }

    public IReadOnlyList<AdminOrderDto> RecentReservations { get; set; } = [];
}
