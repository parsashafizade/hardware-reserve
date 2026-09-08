namespace FinalMvcApp.DTOs.Support;

public class AdminSupportOwnerDto
{
    public string OwnerType { get; set; } = string.Empty;

    public int? UserId { get; set; }

    public string? FullName { get; set; }

    public string? Email { get; set; }
}
