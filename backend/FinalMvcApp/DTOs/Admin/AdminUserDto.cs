namespace FinalMvcApp.DTOs.Admin;

public class AdminUserDto
{
    public int Id { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Role { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public bool IsEmailVerified { get; set; }
}
