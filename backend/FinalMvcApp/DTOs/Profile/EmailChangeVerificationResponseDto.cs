using FinalMvcApp.DTOs.Auth;

namespace FinalMvcApp.DTOs.Profile;

public class EmailChangeVerificationResponseDto
{
    public bool Completed { get; set; }

    public EmailChangeStatusDto? Status { get; set; }

    public AuthResponseDto? Authentication { get; set; }
}
