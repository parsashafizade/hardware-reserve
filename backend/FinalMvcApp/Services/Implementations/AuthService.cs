using AutoMapper;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Services;
using Microsoft.Extensions.Options;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using FinalMvcApp.Errors;

namespace FinalMvcApp.Services.Implementations;

public class AuthService : IAuthService
{
    private readonly IEmailVerificationService _emailVerificationService;
    private readonly IPasswordResetCodeService _passwordResetCodeService;
    private readonly IUserRepository _userRepository;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IPasswordResetTokenRepository _passwordResetTokenRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly ICaptchaService _captchaService;
    private readonly IEmailSender _emailSender;
    private readonly JwtSettings _jwtSettings;
    private readonly IMapper _mapper;


    public AuthService(
        IUserRepository userRepository,
        IRefreshTokenRepository refreshTokenRepository,
        IPasswordResetTokenRepository passwordResetTokenRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService,
        ICaptchaService captchaService,
        IEmailSender emailSender,
        IEmailVerificationService emailVerificationService,
        IPasswordResetCodeService passwordResetCodeService,
        IOptions<JwtSettings> jwtOptions,
        IMapper mapper)
    {
        _userRepository = userRepository;
        _refreshTokenRepository = refreshTokenRepository;
        _passwordResetTokenRepository = passwordResetTokenRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
        _captchaService = captchaService;
        _emailSender = emailSender;
        _emailVerificationService = emailVerificationService;
        _passwordResetCodeService = passwordResetCodeService;
        _jwtSettings = jwtOptions.Value;
        _mapper = mapper;
    }

    public CaptchaChallengeResponseDto GetCaptcha()
    {
        return _captchaService.CreateChallenge();
    }

    public async Task<AuthResponseDto> VerifyEmailAsync(
    VerifyEmailRequestDto request,
    string ipAddress,
    CancellationToken cancellationToken = default)
    {
        var normalizedEmail = EmailAddressNormalizer.Normalize(request.Email);

        var user = await _userRepository.GetByEmailAsync(
            normalizedEmail,
            cancellationToken);

        if (user is null)
        {
            throw new ApiException(
            ApiErrorCodes.EmailVerificationCodeInvalid,
            "Verification code is invalid or expired.",
            StatusCodes.Status400BadRequest);
        }

        if (user.IsEmailVerified)
        {
            throw new ApiException(
                ApiErrorCodes.EmailAlreadyVerified,
                "Email is already verified.",
                StatusCodes.Status409Conflict);
        }

        await _emailVerificationService.ValidateAndConsumeAsync(
            user.Id,
            request.Code,
            cancellationToken);

        user.IsEmailVerified = true;
        user.EmailVerifiedAt = DateTime.UtcNow;

        _userRepository.Update(user);
        await _userRepository.SaveChangesAsync(cancellationToken);

        return await BuildAuthResponseAsync(
            user,
            ipAddress,
            cancellationToken);
    }

    public async Task<AuthResponseDto> LoginAsync(LoginRequestDto request, string ipAddress, CancellationToken cancellationToken = default)
    {
        _captchaService.ValidateAndConsume(request.CaptchaId, request.CaptchaAnswer);

        var normalizedIdentifier = EmailAddressNormalizer.Normalize(request.Identifier);
        var user = await _userRepository.GetByEmailAsync(normalizedIdentifier, cancellationToken);

        if (user is null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            throw new ApiException(
                 ApiErrorCodes.InvalidCredentials,
                 "Invalid credentials.",
                 StatusCodes.Status401Unauthorized);
        }
        if (!user.IsEmailVerified)
        {
            throw new ApiException(
                ApiErrorCodes.EmailVerificationRequired,
                "Email verification is required.",
                StatusCodes.Status403Forbidden);
        }

        return await BuildAuthResponseAsync(user, ipAddress, cancellationToken);
    }

    public async Task<AuthResponseDto> RefreshAsync(
    RefreshTokenRequestDto request,
    string ipAddress,
    CancellationToken cancellationToken = default)
    {
        var refreshToken = await _refreshTokenRepository.GetByTokenAsync(
            request.RefreshToken,
            cancellationToken);

        if (refreshToken is null
            || refreshToken.RevokedAt is not null
            || refreshToken.ExpiresAt <= DateTime.UtcNow)
        {
            throw new ApiException(
                ApiErrorCodes.InvalidRefreshToken,
                "Invalid refresh token.",
                StatusCodes.Status401Unauthorized);
        }

        refreshToken.RevokedAt = DateTime.UtcNow;
        _refreshTokenRepository.Update(refreshToken);

        var rotatedToken = CreateRefreshToken(
            refreshToken.UserId,
            ipAddress);

        await _refreshTokenRepository.AddAsync(
            rotatedToken,
            cancellationToken);

        try
        {
            await _refreshTokenRepository.SaveChangesAsync(
                cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ApiException(
                ApiErrorCodes.InvalidRefreshToken,
                "Invalid refresh token.",
                StatusCodes.Status401Unauthorized);
        }

        var (accessToken, accessTokenExpiresAt) =
            _jwtTokenService.GenerateAccessToken(refreshToken.User);

        return new AuthResponseDto
        {
            AccessToken = accessToken,
            AccessTokenExpiresAt = accessTokenExpiresAt,
            RefreshToken = rotatedToken.Token,
            RefreshTokenExpiresAt = rotatedToken.ExpiresAt,
            User = _mapper.Map<AuthenticatedUserDto>(refreshToken.User)
        };
    }

    public async Task<RegisterResponseDto> RegisterAsync(
        RegisterRequestDto request,
        CancellationToken cancellationToken = default)
    {
        _captchaService.ValidateAndConsume(
            request.CaptchaId,
            request.CaptchaAnswer);

        var normalizedEmail = EmailAddressNormalizer.Normalize(request.Email);

        var emailInUse = await _userRepository.EmailExistsAsync(
            normalizedEmail,
            cancellationToken: cancellationToken);

        if (emailInUse)
        {
            throw new ApiException(
                ApiErrorCodes.EmailAlreadyExists,
                "Email already exists.",
                StatusCodes.Status409Conflict);
        }

        var user = new User
        {
            FullName = request.FullName.Trim(),
            Email = normalizedEmail,
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = false,
            EmailVerifiedAt = null
        };

        await _userRepository.AddAsync(user, cancellationToken);
        await _userRepository.SaveChangesAsync(cancellationToken);

        var issuedCode = await _emailVerificationService.IssueCodeAsync(
            user.Id,
            enforceResendCooldown: false,
            cancellationToken)
            ?? throw new InvalidOperationException(
                "Unable to issue an email verification code.");

        await _emailSender.SendEmailVerificationCodeAsync(
            user.Email,
            user.FullName,
            issuedCode.Code,
            issuedCode.ExpiresAtUtc,
            cancellationToken);

        return new RegisterResponseDto
        {
            Email = user.Email,
            RequiresEmailVerification = true,
            Message = "Verification code sent."
        };
    }

    public async Task ResendVerificationCodeAsync(
    ResendVerificationCodeRequestDto request,
    CancellationToken cancellationToken = default)
    {
        var normalizedEmail = EmailAddressNormalizer.Normalize(request.Email);

        var user = await _userRepository.GetByEmailAsync(
            normalizedEmail,
            cancellationToken);

        if (user is null || user.IsEmailVerified)
        {
            return;
        }

        var issuedCode = await _emailVerificationService.IssueCodeAsync(
            user.Id,
            enforceResendCooldown: true,
            cancellationToken);

        if (issuedCode is null)
        {
            return;
        }

        await _emailSender.SendEmailVerificationCodeAsync(
            user.Email,
            user.FullName,
            issuedCode.Code,
            issuedCode.ExpiresAtUtc,
            cancellationToken);
    }

    public async Task LogoutAsync(LogoutRequestDto request, CancellationToken cancellationToken = default)
    {
        var refreshToken = await _refreshTokenRepository.GetByTokenAsync(request.RefreshToken, cancellationToken);

        if (refreshToken is null || refreshToken.RevokedAt is not null)
        {
            return;
        }

        refreshToken.RevokedAt = DateTime.UtcNow;
        _refreshTokenRepository.Update(refreshToken);

        try
        {
            await _refreshTokenRepository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // A concurrent refresh or logout already consumed this token.
            // Logout is intentionally idempotent.
        }
    }

    public async Task ForgotPasswordAsync(
        ForgotPasswordRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var normalizedEmail = EmailAddressNormalizer.Normalize(request.Email);

        var user = await _userRepository.GetByEmailAsync(
            normalizedEmail,
            cancellationToken);

        if (user is null)
        {
            return;
        }

        var issuedCode = await _passwordResetCodeService.IssueCodeAsync(
            user.Id,
            enforceCooldown: true,
            cancellationToken);

        if (issuedCode is null)
        {
            return;
        }

        await _emailSender.SendPasswordResetCodeAsync(
            user.Email,
            user.FullName,
            issuedCode.Code,
            issuedCode.ExpiresAtUtc,
            cancellationToken);
    }

    public async Task<VerifyPasswordResetCodeResponseDto>
    VerifyPasswordResetCodeAsync(
        VerifyPasswordResetCodeRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var normalizedEmail = EmailAddressNormalizer.Normalize(request.Email);

        var user = await _userRepository.GetByEmailAsync(
            normalizedEmail,
            cancellationToken);

        if (user is null)
        {
            throw new ApiException(
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        await _passwordResetCodeService.ValidateAndConsumeAsync(
            user.Id,
            request.Code,
            cancellationToken);

        var existingTokens =
            await _passwordResetTokenRepository.GetByUserIdAsync(
                user.Id,
                cancellationToken);

        foreach (var existingToken in existingTokens)
        {
            _passwordResetTokenRepository.Delete(existingToken);
        }

        var expiresAtUtc = DateTime.UtcNow.AddMinutes(15);

        var resetToken = new PasswordResetToken
        {
            UserId = user.Id,
            Token = CreateSecureToken(48),
            ExpiryDate = expiresAtUtc
        };

        await _passwordResetTokenRepository.AddAsync(
            resetToken,
            cancellationToken);

        await _passwordResetTokenRepository.SaveChangesAsync(
            cancellationToken);

        return new VerifyPasswordResetCodeResponseDto
        {
            ResetToken = resetToken.Token,
            ExpiresAtUtc = expiresAtUtc
        };
    }

    public async Task<AuthResponseDto> ResetPasswordAsync(
        ResetPasswordRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default)
    {
        var passwordResetToken =
            await _passwordResetTokenRepository.GetByTokenAsync(
                request.Token,
                cancellationToken);

        if (passwordResetToken is null ||
            passwordResetToken.ExpiryDate <= DateTime.UtcNow)
        {
            throw new ApiException(
                ApiErrorCodes.PasswordResetTokenInvalid,
                "Reset token is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        var user = passwordResetToken.User;
        var now = DateTime.UtcNow;

        user.PasswordHash =
            _passwordHasher.HashPassword(
                request.NewPassword);

        _userRepository.Update(user);

        // Revoke every session that existed before the password reset.
        var refreshTokens =
            await _refreshTokenRepository.GetByUserIdAsync(
                user.Id,
                cancellationToken);

        foreach (var refreshToken in refreshTokens)
        {
            if (refreshToken.RevokedAt is not null)
            {
                continue;
            }

            refreshToken.RevokedAt = now;
            _refreshTokenRepository.Update(refreshToken);
        }

        // Invalidate every outstanding password-reset token.
        var resetTokens =
            await _passwordResetTokenRepository.GetByUserIdAsync(
                user.Id,
                cancellationToken);

        foreach (var resetToken in resetTokens)
        {
            _passwordResetTokenRepository.Delete(resetToken);
        }

        // All repositories use the same scoped DbContext,
        // so this commits the password change, revocations,
        // and reset-token deletions together.
        try
        {
            await _refreshTokenRepository.SaveChangesAsync(
                cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ApiException(
                ApiErrorCodes.PasswordResetTokenInvalid,
                "Reset token is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        // A fresh session is created only after old sessions are revoked.
        return await BuildAuthResponseAsync(
            user,
            ipAddress,
            cancellationToken);
    }

    private async Task<AuthResponseDto> BuildAuthResponseAsync(User user, string ipAddress, CancellationToken cancellationToken)
    {
        var refreshToken = CreateRefreshToken(user.Id, ipAddress);
        await _refreshTokenRepository.AddAsync(refreshToken, cancellationToken);
        await _refreshTokenRepository.SaveChangesAsync(cancellationToken);

        var (accessToken, accessTokenExpiresAt) = _jwtTokenService.GenerateAccessToken(user);

        return new AuthResponseDto
        {
            AccessToken = accessToken,
            AccessTokenExpiresAt = accessTokenExpiresAt,
            RefreshToken = refreshToken.Token,
            RefreshTokenExpiresAt = refreshToken.ExpiresAt,
            User = _mapper.Map<AuthenticatedUserDto>(user)
        };
    }

    public async Task<AuthResponseDto> IssueSessionAsync(
        int userId,
        string ipAddress,
        CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(
            userId,
            cancellationToken)
            ?? throw new KeyNotFoundException("User profile was not found.");

        return await BuildAuthResponseAsync(
            user,
            ipAddress,
            cancellationToken);
    }

    private RefreshToken CreateRefreshToken(int userId, string ipAddress)
    {
        return new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Token = CreateSecureToken(64),
            CreatedAt = DateTime.UtcNow,
            CreatedByIp = string.IsNullOrWhiteSpace(ipAddress) ? "unknown" : ipAddress,
            ExpiresAt = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenDays)
        };
    }

    private static string CreateSecureToken(int byteCount)
    {
        var bytes = RandomNumberGenerator.GetBytes(byteCount);
        return Convert.ToBase64String(bytes);
    }
}
