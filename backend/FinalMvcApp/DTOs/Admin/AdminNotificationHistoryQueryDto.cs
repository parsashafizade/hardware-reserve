namespace FinalMvcApp.DTOs.Admin;

public class AdminNotificationHistoryQueryDto
{
    public string? Source { get; set; }

    public string? Type { get; set; }

    public int? UserId { get; set; }

    public bool? IsRead { get; set; }

    public int Page { get; set; } = 1;

    public int PageSize { get; set; } = 20;
}
