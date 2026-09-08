namespace FinalMvcApp.DTOs.Notifications;

public class NotificationQueryDto
{
    public string? Cursor { get; set; }

    public int PageSize { get; set; } = 20;
}
