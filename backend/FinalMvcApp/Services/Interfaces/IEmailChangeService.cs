using FinalMvcApp.DTOs.Profile;

namespace FinalMvcApp.Services.Interfaces;

public interface IEmailChangeService
{
    Task<EmailChangeStatusDto?> GetStatusAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<EmailChangeStatusDto> StartAsync(
        int userId,
        StartEmailChangeRequestDto request,
        CancellationToken cancellationToken = default);

    Task<EmailChangeVerificationResponseDto> VerifyCurrentAsync(
        int userId,
        VerifyEmailChangeCodeRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default);

    Task<EmailChangeVerificationResponseDto> VerifyNewAsync(
        int userId,
        VerifyEmailChangeCodeRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default);

    Task<EmailChangeStatusDto> ResendCurrentAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<EmailChangeStatusDto> ResendNewAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task CancelAsync(
        int userId,
        CancellationToken cancellationToken = default);
}
