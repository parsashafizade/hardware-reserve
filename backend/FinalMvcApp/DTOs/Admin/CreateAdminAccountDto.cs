namespace FinalMvcApp.DTOs.Admin;

public class CreateAdminAccountDto
{
    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;
}
