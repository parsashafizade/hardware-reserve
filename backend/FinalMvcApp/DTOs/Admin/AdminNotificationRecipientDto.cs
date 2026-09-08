namespace FinalMvcApp.DTOs.Admin;

public class AdminNotificationRecipientDto
{
    public int Id { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;
}
