using AutoMapper;
using FinalMvcApp.DTOs.Profile;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class ProfileService : IProfileService
{
    private const long MaxProfileImageBytes = 2 * 1024 * 1024;
    private static readonly HashSet<string> AllowedImageExtensions =
    [
        ".jpg",
        ".jpeg",
        ".png",
        ".webp"
    ];

    private readonly IUserRepository _userRepository;
    private readonly IMapper _mapper;
    private readonly IWebHostEnvironment _webHostEnvironment;

    public ProfileService(IUserRepository userRepository, IMapper mapper, IWebHostEnvironment webHostEnvironment)
    {
        _userRepository = userRepository;
        _mapper = mapper;
        _webHostEnvironment = webHostEnvironment;
    }

    public async Task<ProfileResponseDto> GetAsync(int userId, CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User profile was not found.");

        return _mapper.Map<ProfileResponseDto>(user);
    }

    public async Task<ProfileResponseDto> UpdateAsync(int userId, UpdateProfileRequestDto request, CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User profile was not found.");

        user.FullName = request.FullName.Trim();

        _userRepository.Update(user);
        await _userRepository.SaveChangesAsync(cancellationToken);

        return _mapper.Map<ProfileResponseDto>(user);
    }

    public async Task<ProfileResponseDto> UploadProfileImageAsync(
        int userId,
        IFormFile file,
        CancellationToken cancellationToken = default)
    {
        if (file is null || file.Length <= 0)
        {
            throw new InvalidOperationException("Profile image file is required.");
        }

        if (file.Length > MaxProfileImageBytes)
        {
            throw new InvalidOperationException("Profile image must be 2MB or smaller.");
        }

        var extension = Path.GetExtension(file.FileName);
        if (string.IsNullOrWhiteSpace(extension)
            || !AllowedImageExtensions.Contains(extension.Trim().ToLowerInvariant()))
        {
            throw new InvalidOperationException("Only JPG, PNG, and WEBP images are supported.");
        }

        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User profile was not found.");

        var webRootPath = _webHostEnvironment.WebRootPath;
        if (string.IsNullOrWhiteSpace(webRootPath))
        {
            webRootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        }

        var uploadsDirectory = Path.Combine(webRootPath, "uploads");
        Directory.CreateDirectory(uploadsDirectory);

        var fileName = $"profile-{userId}-{Guid.NewGuid():N}{extension.ToLowerInvariant()}";
        var fullPath = Path.Combine(uploadsDirectory, fileName);

        await using (var stream = new FileStream(fullPath, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            await file.CopyToAsync(stream, cancellationToken);
        }

        DeletePreviousImageIfExists(user.ProfileImagePath, webRootPath);

        user.ProfileImagePath = $"/uploads/{fileName}";
        _userRepository.Update(user);
        await _userRepository.SaveChangesAsync(cancellationToken);

        return _mapper.Map<ProfileResponseDto>(user);
    }

    private static void DeletePreviousImageIfExists(string? imagePath, string webRootPath)
    {
        if (string.IsNullOrWhiteSpace(imagePath))
        {
            return;
        }

        var relativePath = imagePath.Trim().TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        if (!relativePath.StartsWith($"uploads{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(relativePath, "uploads", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var absolutePath = Path.Combine(webRootPath, relativePath);
        if (File.Exists(absolutePath))
        {
            File.Delete(absolutePath);
        }
    }
}
