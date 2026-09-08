using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.DTOs.Profile;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace FinalMvcApp.Services.Implementations;

public class EmailChangeService : IEmailChangeService
{
    private const int CodeUpperBound = 1_000_000;
    private static readonly TimeSpan RequestLifetime = TimeSpan.FromMinutes(30);

    private readonly IPendingEmailChangeRepository _emailChangeRepository;
    private readonly IUserRepository _userRepository;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IEmailSender _emailSender;
    private readonly IAuthService _authService;
    private readonly EmailVerificationSettings _settings;
    private readonly byte[] _hmacKey;

    public EmailChangeService(
        IPendingEmailChangeRepository emailChangeRepository,
        IUserRepository userRepository,
        IRefreshTokenRepository refreshTokenRepository,
        IEmailSender emailSender,
        IAuthService authService,
        IOptions<EmailVerificationSettings> options)
    {
        _emailChangeRepository = emailChangeRepository;
        _userRepository = userRepository;
        _refreshTokenRepository = refreshTokenRepository;
        _emailSender = emailSender;
        _authService = authService;
        _settings = options.Value;

        if (string.IsNullOrWhiteSpace(_settings.HmacKey)
            || _settings.HmacKey.Length < 32)
        {
            throw new InvalidOperationException(
                "Email verification HMAC key must be at least 32 characters.");
        }

        if (_settings.CodeLifetimeMinutes is < 1 or > 60
            || _settings.ResendCooldownSeconds is < 0 or > 3600
            || _settings.MaxAttempts is < 1 or > 20)
        {
            throw new InvalidOperationException(
                "Email verification settings are invalid.");
        }

        _hmacKey = Encoding.UTF8.GetBytes(_settings.HmacKey);
    }

    public async Task<EmailChangeStatusDto?> GetStatusAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var change = await _emailChangeRepository.GetByUserIdAsync(
            userId,
            cancellationToken);

        if (change is null
            || change.CompletedAt is not null
            || change.InvalidatedAt is not null)
        {
            return null;
        }

        if (change.ExpiresAt <= DateTime.UtcNow)
        {
            change.InvalidatedAt = DateTime.UtcNow;
            change.UpdatedAt = change.InvalidatedAt.Value;

            try
            {
                await _emailChangeRepository.SaveChangesAsync(
                    cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                return null;
            }

            return null;
        }

        return ToStatus(change);
    }

    public async Task<EmailChangeStatusDto> StartAsync(
        int userId,
        StartEmailChangeRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var user = await GetUserAsync(userId, cancellationToken);
        var currentEmail = EmailAddressNormalizer.Normalize(user.Email);
        var newEmail = EmailAddressNormalizer.Normalize(request.NewEmail);

        if (string.Equals(
                currentEmail,
                newEmail,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new ApiException(
                ApiErrorCodes.EmailChangeSameEmail,
                "The new email must be different from the current email.",
                StatusCodes.Status400BadRequest);
        }

        if (await _userRepository.EmailExistsAsync(
                newEmail,
                userId,
                cancellationToken))
        {
            throw EmailInUseException();
        }

        var now = DateTime.UtcNow;
        var change = await _emailChangeRepository.GetByUserIdAsync(
            userId,
            cancellationToken);
        var previousCurrent = change is null
            ? null
            : new PreviousCode(
                change.Id,
                change.CurrentEmail,
                change.CurrentCodeHash,
                CodeDestination.Current);
        var previousNew = change is null
            ? null
            : new PreviousCode(
                change.Id,
                change.NewEmail,
                change.NewCodeHash,
                CodeDestination.New);

        if (change is null)
        {
            change = new PendingEmailChange
            {
                Id = Guid.NewGuid(),
                UserId = userId
            };

            await _emailChangeRepository.AddAsync(
                change,
                cancellationToken);
        }

        change.CurrentEmail = currentEmail;
        change.NewEmail = newEmail;
        change.CreatedAt = now;
        change.UpdatedAt = now;
        change.ExpiresAt = now.Add(RequestLifetime);
        change.CompletedAt = null;
        change.InvalidatedAt = null;
        change.CurrentEmailVerifiedAt = null;
        change.NewEmailVerifiedAt = null;
        change.CurrentCodeUsedAt = null;
        change.NewCodeUsedAt = null;
        change.CurrentAttemptCount = 0;
        change.NewAttemptCount = 0;
        change.CurrentCodeCreatedAt = now;
        change.NewCodeCreatedAt = now;
        change.CurrentCodeExpiresAt = GetCodeExpiry(now, change.ExpiresAt);
        change.NewCodeExpiresAt = GetCodeExpiry(now, change.ExpiresAt);

        var currentCode = GenerateCode(previousCurrent);
        var newCode = GenerateCode(previousNew, currentCode);

        change.CurrentCodeHash = HashCode(
            change,
            CodeDestination.Current,
            currentCode);
        change.NewCodeHash = HashCode(
            change,
            CodeDestination.New,
            newCode);

        await SaveRequestStateAsync(cancellationToken);

        await _emailSender.SendCurrentEmailChangeCodeAsync(
            change.CurrentEmail,
            user.FullName,
            currentCode,
            change.CurrentCodeExpiresAt,
            cancellationToken);

        await _emailSender.SendNewEmailChangeCodeAsync(
            change.NewEmail,
            user.FullName,
            newCode,
            change.NewCodeExpiresAt,
            cancellationToken);

        return ToStatus(change);
    }

    public Task<EmailChangeVerificationResponseDto> VerifyCurrentAsync(
        int userId,
        VerifyEmailChangeCodeRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default)
    {
        return VerifyAsync(
            userId,
            request.Code,
            CodeDestination.Current,
            ipAddress,
            cancellationToken);
    }

    public Task<EmailChangeVerificationResponseDto> VerifyNewAsync(
        int userId,
        VerifyEmailChangeCodeRequestDto request,
        string ipAddress,
        CancellationToken cancellationToken = default)
    {
        return VerifyAsync(
            userId,
            request.Code,
            CodeDestination.New,
            ipAddress,
            cancellationToken);
    }

    public Task<EmailChangeStatusDto> ResendCurrentAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return ResendAsync(
            userId,
            CodeDestination.Current,
            cancellationToken);
    }

    public Task<EmailChangeStatusDto> ResendNewAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        return ResendAsync(
            userId,
            CodeDestination.New,
            cancellationToken);
    }

    public async Task CancelAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var change = await _emailChangeRepository.GetByUserIdAsync(
            userId,
            cancellationToken);

        if (change is null
            || change.CompletedAt is not null
            || change.InvalidatedAt is not null)
        {
            return;
        }

        var now = DateTime.UtcNow;
        change.InvalidatedAt = now;
        change.UpdatedAt = now;

        await SaveRequestStateAsync(cancellationToken);
    }

    private async Task<EmailChangeVerificationResponseDto> VerifyAsync(
        int userId,
        string code,
        CodeDestination destination,
        string ipAddress,
        CancellationToken cancellationToken)
    {
        var normalizedCode = code.Trim();

        if (normalizedCode.Length != 6
            || normalizedCode.Any(character => character is < '0' or > '9'))
        {
            throw InvalidCodeException();
        }

        var change = await GetActiveChangeAsync(userId, cancellationToken);
        var user = await GetUserAsync(userId, cancellationToken);

        if (!string.Equals(
                EmailAddressNormalizer.Normalize(user.Email),
                change.CurrentEmail,
                StringComparison.Ordinal))
        {
            change.InvalidatedAt = DateTime.UtcNow;
            change.UpdatedAt = change.InvalidatedAt.Value;
            await SaveRequestStateAsync(cancellationToken);
            throw InvalidRequestException();
        }

        var verifiedAt = GetVerifiedAt(change, destination);
        var usedAt = GetUsedAt(change, destination);

        if (verifiedAt is not null)
        {
            throw new ApiException(
                ApiErrorCodes.EmailChangeAlreadyVerified,
                "This email address has already been verified for the pending change.",
                StatusCodes.Status409Conflict);
        }

        if (usedAt is not null)
        {
            throw InvalidCodeException();
        }

        var now = DateTime.UtcNow;

        if (GetCodeExpiresAt(change, destination) <= now)
        {
            SetUsedAt(change, destination, now);
            change.UpdatedAt = now;
            await SaveRequestStateAsync(cancellationToken);
            throw InvalidCodeException();
        }

        if (!CodeMatches(
                change,
                destination,
                normalizedCode,
                GetCodeHash(change, destination)))
        {
            var attempts = GetAttemptCount(change, destination) + 1;
            SetAttemptCount(change, destination, attempts);

            if (attempts >= _settings.MaxAttempts)
            {
                SetUsedAt(change, destination, now);
            }

            change.UpdatedAt = now;
            await SaveRequestStateAsync(cancellationToken);
            throw InvalidCodeException();
        }

        SetUsedAt(change, destination, now);
        SetVerifiedAt(change, destination, now);
        change.UpdatedAt = now;

        if (change.CurrentEmailVerifiedAt is not null
            && change.NewEmailVerifiedAt is not null)
        {
            var authentication = await CompleteAsync(
                user,
                change,
                ipAddress,
                cancellationToken);

            return new EmailChangeVerificationResponseDto
            {
                Completed = true,
                Authentication = authentication
            };
        }

        await SaveRequestStateAsync(cancellationToken);

        return new EmailChangeVerificationResponseDto
        {
            Completed = false,
            Status = ToStatus(change)
        };
    }

    private async Task<EmailChangeStatusDto> ResendAsync(
        int userId,
        CodeDestination destination,
        CancellationToken cancellationToken)
    {
        var change = await GetActiveChangeAsync(userId, cancellationToken);
        var user = await GetUserAsync(userId, cancellationToken);

        if (GetVerifiedAt(change, destination) is not null)
        {
            throw new ApiException(
                ApiErrorCodes.EmailChangeAlreadyVerified,
                "This email address has already been verified for the pending change.",
                StatusCodes.Status409Conflict);
        }

        var now = DateTime.UtcNow;
        var resendAvailableAt = GetCodeCreatedAt(change, destination)
            .AddSeconds(_settings.ResendCooldownSeconds);

        if (resendAvailableAt > now)
        {
            throw new ApiException(
                ApiErrorCodes.EmailChangeResendTooSoon,
                "Please wait before requesting another code.",
                StatusCodes.Status429TooManyRequests);
        }

        var code = GenerateReplacementCode(change, destination);
        var expiresAt = GetCodeExpiry(now, change.ExpiresAt);

        SetCodeHash(change, destination, HashCode(change, destination, code));
        SetCodeCreatedAt(change, destination, now);
        SetCodeExpiresAt(change, destination, expiresAt);
        SetUsedAt(change, destination, null);
        SetAttemptCount(change, destination, 0);
        change.UpdatedAt = now;

        await SaveRequestStateAsync(cancellationToken);

        if (destination == CodeDestination.Current)
        {
            await _emailSender.SendCurrentEmailChangeCodeAsync(
                change.CurrentEmail,
                user.FullName,
                code,
                expiresAt,
                cancellationToken);
        }
        else
        {
            await _emailSender.SendNewEmailChangeCodeAsync(
                change.NewEmail,
                user.FullName,
                code,
                expiresAt,
                cancellationToken);
        }

        return ToStatus(change);
    }

    private async Task<AuthResponseDto> CompleteAsync(
        User user,
        PendingEmailChange change,
        string ipAddress,
        CancellationToken cancellationToken)
    {
        if (await _userRepository.EmailExistsAsync(
                change.NewEmail,
                user.Id,
                cancellationToken))
        {
            throw EmailInUseException();
        }

        var now = DateTime.UtcNow;
        user.Email = change.NewEmail;
        user.IsEmailVerified = true;
        user.EmailVerifiedAt = now;
        change.CompletedAt = now;
        change.UpdatedAt = now;

        _userRepository.Update(user);

        var refreshTokens = await _refreshTokenRepository.GetByUserIdAsync(
            user.Id,
            cancellationToken);

        foreach (var refreshToken in refreshTokens)
        {
            if (refreshToken.RevokedAt is null)
            {
                refreshToken.RevokedAt = now;
                _refreshTokenRepository.Update(refreshToken);
            }
        }

        try
        {
            await _emailChangeRepository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw InvalidRequestException();
        }
        catch (DbUpdateException exception)
            when (IsUserEmailUniqueViolation(exception))
        {
            throw EmailInUseException();
        }

        return await _authService.IssueSessionAsync(
            user.Id,
            ipAddress,
            cancellationToken);
    }

    private async Task<PendingEmailChange> GetActiveChangeAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var change = await _emailChangeRepository.GetByUserIdAsync(
            userId,
            cancellationToken);

        if (change is null
            || change.CompletedAt is not null
            || change.InvalidatedAt is not null)
        {
            throw InvalidRequestException();
        }

        if (change.ExpiresAt <= DateTime.UtcNow)
        {
            change.InvalidatedAt = DateTime.UtcNow;
            change.UpdatedAt = change.InvalidatedAt.Value;
            await SaveRequestStateAsync(cancellationToken);
            throw InvalidRequestException();
        }

        return change;
    }

    private async Task<User> GetUserAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        return await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User profile was not found.");
    }

    private async Task SaveRequestStateAsync(
        CancellationToken cancellationToken)
    {
        try
        {
            await _emailChangeRepository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw InvalidRequestException();
        }
        catch (DbUpdateException exception)
            when (IsPendingRequestUniqueViolation(exception))
        {
            throw InvalidRequestException();
        }
    }

    private string GenerateCode(
        PreviousCode? previousCode = null,
        string? forbiddenCode = null)
    {
        string code;

        do
        {
            code = RandomNumberGenerator
                .GetInt32(0, CodeUpperBound)
                .ToString("D6", CultureInfo.InvariantCulture);
        }
        while (string.Equals(code, forbiddenCode, StringComparison.Ordinal)
               || PreviousCodeMatches(previousCode, code));

        return code;
    }

    private string GenerateReplacementCode(
        PendingEmailChange change,
        CodeDestination destination)
    {
        var otherDestination = destination == CodeDestination.Current
            ? CodeDestination.New
            : CodeDestination.Current;
        string code;

        do
        {
            code = RandomNumberGenerator
                .GetInt32(0, CodeUpperBound)
                .ToString("D6", CultureInfo.InvariantCulture);
        }
        while (CodeMatches(
                   change,
                   destination,
                   code,
                   GetCodeHash(change, destination))
               || CodeMatches(
                   change,
                   otherDestination,
                   code,
                   GetCodeHash(change, otherDestination)));

        return code;
    }

    private bool PreviousCodeMatches(PreviousCode? previous, string code)
    {
        if (previous is null || string.IsNullOrWhiteSpace(previous.CodeHash))
        {
            return false;
        }

        var hash = ComputeHash(
            previous.RequestId,
            previous.Email,
            previous.Destination,
            code);

        return HashMatches(hash, previous.CodeHash);
    }

    private string HashCode(
        PendingEmailChange change,
        CodeDestination destination,
        string code)
    {
        return Convert.ToHexString(
            ComputeHash(
                change.Id,
                GetEmail(change, destination),
                destination,
                code));
    }

    private bool CodeMatches(
        PendingEmailChange change,
        CodeDestination destination,
        string code,
        string expectedHash)
    {
        var actual = ComputeHash(
            change.Id,
            GetEmail(change, destination),
            destination,
            code);

        return HashMatches(actual, expectedHash);
    }

    private byte[] ComputeHash(
        Guid requestId,
        string email,
        CodeDestination destination,
        string code)
    {
        using var hmac = new HMACSHA256(_hmacKey);
        var purpose = destination == CodeDestination.Current
            ? "current"
            : "new";
        var value = Encoding.UTF8.GetBytes(
            $"email-change:{purpose}:{requestId:N}:{email}:{code}");

        return hmac.ComputeHash(value);
    }

    private static bool HashMatches(byte[] actual, string expectedHash)
    {
        byte[] expected;

        try
        {
            expected = Convert.FromHexString(expectedHash);
        }
        catch (FormatException)
        {
            return false;
        }

        return expected.Length == actual.Length
            && CryptographicOperations.FixedTimeEquals(expected, actual);
    }

    private static bool IsUserEmailUniqueViolation(DbUpdateException exception)
    {
        return exception.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation,
            ConstraintName: "IX_Users_Email"
        };
    }

    private static bool IsPendingRequestUniqueViolation(
        DbUpdateException exception)
    {
        return exception.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation,
            ConstraintName: "IX_PendingEmailChanges_UserId"
        };
    }

    private DateTime GetCodeExpiry(DateTime now, DateTime requestExpiresAt)
    {
        var codeExpiresAt = now.AddMinutes(_settings.CodeLifetimeMinutes);
        return codeExpiresAt < requestExpiresAt
            ? codeExpiresAt
            : requestExpiresAt;
    }

    private EmailChangeStatusDto ToStatus(PendingEmailChange change)
    {
        return new EmailChangeStatusDto
        {
            CurrentEmail = change.CurrentEmail,
            NewEmail = change.NewEmail,
            CurrentEmailVerified = change.CurrentEmailVerifiedAt is not null,
            NewEmailVerified = change.NewEmailVerifiedAt is not null,
            CurrentCodeExpiresAtUtc = change.CurrentCodeExpiresAt,
            NewCodeExpiresAtUtc = change.NewCodeExpiresAt,
            CurrentResendAvailableAtUtc = change.CurrentCodeCreatedAt
                .AddSeconds(_settings.ResendCooldownSeconds),
            NewResendAvailableAtUtc = change.NewCodeCreatedAt
                .AddSeconds(_settings.ResendCooldownSeconds),
            ExpiresAtUtc = change.ExpiresAt
        };
    }

    private static string GetEmail(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentEmail
            : change.NewEmail;
    }

    private static string GetCodeHash(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentCodeHash
            : change.NewCodeHash;
    }

    private static void SetCodeHash(
        PendingEmailChange change,
        CodeDestination destination,
        string value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentCodeHash = value;
        }
        else
        {
            change.NewCodeHash = value;
        }
    }

    private static DateTime GetCodeCreatedAt(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentCodeCreatedAt
            : change.NewCodeCreatedAt;
    }

    private static void SetCodeCreatedAt(
        PendingEmailChange change,
        CodeDestination destination,
        DateTime value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentCodeCreatedAt = value;
        }
        else
        {
            change.NewCodeCreatedAt = value;
        }
    }

    private static DateTime GetCodeExpiresAt(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentCodeExpiresAt
            : change.NewCodeExpiresAt;
    }

    private static void SetCodeExpiresAt(
        PendingEmailChange change,
        CodeDestination destination,
        DateTime value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentCodeExpiresAt = value;
        }
        else
        {
            change.NewCodeExpiresAt = value;
        }
    }

    private static DateTime? GetUsedAt(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentCodeUsedAt
            : change.NewCodeUsedAt;
    }

    private static void SetUsedAt(
        PendingEmailChange change,
        CodeDestination destination,
        DateTime? value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentCodeUsedAt = value;
        }
        else
        {
            change.NewCodeUsedAt = value;
        }
    }

    private static int GetAttemptCount(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentAttemptCount
            : change.NewAttemptCount;
    }

    private static void SetAttemptCount(
        PendingEmailChange change,
        CodeDestination destination,
        int value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentAttemptCount = value;
        }
        else
        {
            change.NewAttemptCount = value;
        }
    }

    private static DateTime? GetVerifiedAt(
        PendingEmailChange change,
        CodeDestination destination)
    {
        return destination == CodeDestination.Current
            ? change.CurrentEmailVerifiedAt
            : change.NewEmailVerifiedAt;
    }

    private static void SetVerifiedAt(
        PendingEmailChange change,
        CodeDestination destination,
        DateTime value)
    {
        if (destination == CodeDestination.Current)
        {
            change.CurrentEmailVerifiedAt = value;
        }
        else
        {
            change.NewEmailVerifiedAt = value;
        }
    }

    private static ApiException EmailInUseException()
    {
        return new ApiException(
            ApiErrorCodes.EmailChangeEmailInUse,
            "The new email is already in use.",
            StatusCodes.Status409Conflict);
    }

    private static ApiException InvalidRequestException()
    {
        return new ApiException(
            ApiErrorCodes.EmailChangeInvalid,
            "The pending email change is invalid or expired.",
            StatusCodes.Status400BadRequest);
    }

    private static ApiException InvalidCodeException()
    {
        return new ApiException(
            ApiErrorCodes.EmailChangeCodeInvalid,
            "The email change code is invalid or expired.",
            StatusCodes.Status400BadRequest);
    }

    private sealed record PreviousCode(
        Guid RequestId,
        string Email,
        string CodeHash,
        CodeDestination Destination);

    private enum CodeDestination
    {
        Current,
        New
    }
}
