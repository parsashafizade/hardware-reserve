using FinalMvcApp.DTOs.Profile;

namespace FinalMvcApp.Services.Interfaces;

public interface IProfileService
{
    Task<ProfileResponseDto> GetAsync(int userId, CancellationToken cancellationToken = default);

    Task<ProfileResponseDto> UpdateAsync(int userId, UpdateProfileRequestDto request, CancellationToken cancellationToken = default);

    Task<ProfileResponseDto> UploadProfileImageAsync(int userId, IFormFile file, CancellationToken cancellationToken = default);
}
