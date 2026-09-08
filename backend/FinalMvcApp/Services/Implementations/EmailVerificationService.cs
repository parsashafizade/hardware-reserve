using FinalMvcApp.Models.Entities;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Options;
using Microsoft.EntityFrameworkCore;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using FinalMvcApp.Errors;

namespace FinalMvcApp.Services.Implementations;

public class EmailVerificationService : IEmailVerificationService
{
    private const int CodeUpperBound = 1_000_000;

    private readonly IEmailVerificationCodeRepository _repository;
    private readonly EmailVerificationSettings _settings;
    private readonly byte[] _hmacKey;

    public EmailVerificationService(
        IEmailVerificationCodeRepository repository,
        IOptions<EmailVerificationSettings> options)
    {
        _repository = repository;
        _settings = options.Value;

        if (string.IsNullOrWhiteSpace(_settings.HmacKey)
            || _settings.HmacKey.Length < 32)
        {
            throw new InvalidOperationException(
                "Email verification HMAC key must be at least 32 characters.");
        }

        if (_settings.CodeLifetimeMinutes is < 1 or > 60)
        {
            throw new InvalidOperationException(
                "EmailVerification:CodeLifetimeMinutes is invalid.");
        }

        if (_settings.ResendCooldownSeconds is < 0 or > 3600)
        {
            throw new InvalidOperationException(
                "EmailVerification:ResendCooldownSeconds is invalid.");
        }

        if (_settings.MaxAttempts is < 1 or > 20)
        {
            throw new InvalidOperationException(
                "EmailVerification:MaxAttempts is invalid.");
        }

        _hmacKey = Encoding.UTF8.GetBytes(_settings.HmacKey);
    }

    public async Task<EmailVerificationIssueResult?> IssueCodeAsync(
        int userId,
        bool enforceResendCooldown,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var existingCode = await _repository.GetLatestByUserIdAsync(
            userId,
            cancellationToken);

        if (enforceResendCooldown && existingCode is not null)
        {
            var nextAllowedAt = existingCode.CreatedAt.AddSeconds(
                _settings.ResendCooldownSeconds);

            if (nextAllowedAt > now)
            {
                return null;
            }
        }

        var code = GenerateCode(userId, existingCode?.CodeHash);
        var expiresAtUtc = now.AddMinutes(_settings.CodeLifetimeMinutes);

        if (existingCode is null)
        {
            existingCode = new EmailVerificationCode
            {
                UserId = userId
            };

            await _repository.AddAsync(
                existingCode,
                cancellationToken);
        }

        existingCode.CodeHash = HashCode(userId, code);
        existingCode.CreatedAt = now;
        existingCode.ExpiresAt = expiresAtUtc;
        existingCode.UsedAt = null;
        existingCode.AttemptCount = 0;

        try
        {
            await _repository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return null;
        }

        return new EmailVerificationIssueResult(code, expiresAtUtc);
    }

    public async Task ValidateAndConsumeAsync(
        int userId,
        string code,
        CancellationToken cancellationToken = default)
    {
        var normalizedCode = code.Trim();

        if (normalizedCode.Length != 6
            || normalizedCode.Any(character =>
                character < '0' || character > '9'))
        {
            throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        var verificationCode =
            await _repository.GetLatestUnusedByUserIdAsync(
                userId,
                cancellationToken);

        if (verificationCode is null)
        {
            throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        var now = DateTime.UtcNow;

        if (verificationCode.ExpiresAt <= now
            || verificationCode.AttemptCount >= _settings.MaxAttempts)
        {
            verificationCode.UsedAt = now;
            _repository.Update(verificationCode);
            await SaveValidationStateAsync(cancellationToken);

            throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        if (!CodeMatches(
                userId,
                normalizedCode,
                verificationCode.CodeHash))
        {
            verificationCode.AttemptCount++;

            if (verificationCode.AttemptCount >= _settings.MaxAttempts)
            {
                verificationCode.UsedAt = now;
            }

            _repository.Update(verificationCode);
            await SaveValidationStateAsync(cancellationToken);

            throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        verificationCode.UsedAt = now;

        _repository.Update(verificationCode);
        await SaveValidationStateAsync(cancellationToken);
    }

    private string GenerateCode(int userId, string? previousHash)
    {
        string code;

        do
        {
            var value = RandomNumberGenerator.GetInt32(
                0,
                CodeUpperBound);

            code = value.ToString(
                "D6",
                CultureInfo.InvariantCulture);
        }
        while (previousHash is not null
               && CodeMatches(userId, code, previousHash));

        return code;
    }

    private string HashCode(int userId, string code)
    {
        var hash = ComputeHash(userId, code);
        return Convert.ToHexString(hash);
    }

    private bool CodeMatches(
        int userId,
        string code,
        string expectedHash)
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

        var actual = ComputeHash(userId, code);

        return expected.Length == actual.Length
            && CryptographicOperations.FixedTimeEquals(
                expected,
                actual);
    }

    private byte[] ComputeHash(int userId, string code)
    {
        using var hmac = new HMACSHA256(_hmacKey);

        var value = Encoding.UTF8.GetBytes(
            $"{userId}:{code}");

        return hmac.ComputeHash(value);
    }

    private async Task SaveValidationStateAsync(
        CancellationToken cancellationToken)
    {
        try
        {
            await _repository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ApiException(
                ApiErrorCodes.EmailVerificationCodeInvalid,
                "Verification code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }
    }
}
