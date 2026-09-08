namespace FinalMvcApp.DTOs.Profile;

public class EmailChangeStatusDto
{
    public string CurrentEmail { get; set; } = string.Empty;

    public string NewEmail { get; set; } = string.Empty;

    public bool CurrentEmailVerified { get; set; }

    public bool NewEmailVerified { get; set; }

    public DateTime CurrentCodeExpiresAtUtc { get; set; }

    public DateTime NewCodeExpiresAtUtc { get; set; }

    public DateTime CurrentResendAvailableAtUtc { get; set; }

    public DateTime NewResendAvailableAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }
}
