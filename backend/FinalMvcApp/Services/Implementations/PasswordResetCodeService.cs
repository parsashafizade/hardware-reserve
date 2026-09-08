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

public class PasswordResetCodeService : IPasswordResetCodeService
{
    private readonly IPasswordResetCodeRepository _repository;
    private readonly PasswordResetSettings _settings;
    private readonly byte[] _hmacKey;

    public PasswordResetCodeService(
        IPasswordResetCodeRepository repository,
        IOptions<PasswordResetSettings> options)
    {
        _repository = repository;
        _settings = options.Value;

        if (string.IsNullOrWhiteSpace(_settings.HmacKey)
            || _settings.HmacKey.Length < 32)
        {
            throw new InvalidOperationException(
                "Password reset HMAC key must be at least 32 characters.");
        }

        if (_settings.CodeLifetimeMinutes is < 1 or > 60)
        {
            throw new InvalidOperationException(
                "PasswordReset:CodeLifetimeMinutes is invalid.");
        }

        if (_settings.ResendCooldownSeconds is < 0 or > 3600)
        {
            throw new InvalidOperationException(
                "PasswordReset:ResendCooldownSeconds is invalid.");
        }

        if (_settings.MaxAttempts is < 1 or > 20)
        {
            throw new InvalidOperationException(
                "PasswordReset:MaxAttempts is invalid.");
        }

        _hmacKey = Encoding.UTF8.GetBytes(_settings.HmacKey);
    }

    public async Task<PasswordResetCodeIssueResult?> IssueCodeAsync(
        int userId,
        bool enforceCooldown,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var existingCode = await _repository.GetLatestByUserIdAsync(
            userId,
            cancellationToken);

        if (enforceCooldown
            && existingCode is not null
            && existingCode.CreatedAt.AddSeconds(
                _settings.ResendCooldownSeconds) > now)
        {
            return null;
        }

        var code = GenerateCode(userId, existingCode?.CodeHash);
        var expiresAt = now.AddMinutes(_settings.CodeLifetimeMinutes);

        if (existingCode is null)
        {
            existingCode = new PasswordResetCode
            {
                UserId = userId
            };

            await _repository.AddAsync(existingCode, cancellationToken);
        }

        existingCode.CodeHash = HashCode(userId, code);
        existingCode.CreatedAt = now;
        existingCode.ExpiresAt = expiresAt;
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

        return new PasswordResetCodeIssueResult(
            code,
            expiresAt);
    }

    private string GenerateCode(int userId, string? previousHash)
    {
        string code;

        do
        {
            var value = RandomNumberGenerator.GetInt32(0, 1_000_000);
            code = value.ToString("D6", CultureInfo.InvariantCulture);
        }
        while (previousHash is not null
               && CodeMatches(userId, code, previousHash));

        return code;
    }

    public async Task ValidateAndConsumeAsync(
        int userId,
        string code,
        CancellationToken cancellationToken = default)
    {
        var normalizedCode = code.Trim();

        if (normalizedCode.Length != 6 ||
            normalizedCode.Any(c => c < '0' || c > '9'))
        {
            throw new ApiException(
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        var entity =
            await _repository.GetLatestUnusedByUserIdAsync(
                userId,
                cancellationToken);

        if (entity is null)
        {
            throw new ApiException(
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        var now = DateTime.UtcNow;

        if (entity.ExpiresAt <= now ||
            entity.AttemptCount >= _settings.MaxAttempts)
        {
            entity.UsedAt = now;
            _repository.Update(entity);
            await SaveValidationStateAsync(cancellationToken);

            throw new ApiException(
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        if (!CodeMatches(userId, normalizedCode, entity.CodeHash))
        {
            entity.AttemptCount++;

            if (entity.AttemptCount >= _settings.MaxAttempts)
            {
                entity.UsedAt = now;
            }

            _repository.Update(entity);
            await SaveValidationStateAsync(cancellationToken);

            throw new ApiException(
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }

        entity.UsedAt = now;

        _repository.Update(entity);
        await SaveValidationStateAsync(cancellationToken);
    }

    private string HashCode(int userId, string code)
    {
        using var hmac = new HMACSHA256(_hmacKey);

        var bytes = Encoding.UTF8.GetBytes(
            $"password-reset:{userId}:{code}");

        return Convert.ToHexString(hmac.ComputeHash(bytes));
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

        using var hmac = new HMACSHA256(_hmacKey);

        var bytes = Encoding.UTF8.GetBytes(
            $"password-reset:{userId}:{code}");

        var actual = hmac.ComputeHash(bytes);

        return expected.Length == actual.Length &&
            CryptographicOperations.FixedTimeEquals(expected, actual);
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
                ApiErrorCodes.PasswordResetCodeInvalid,
                "Password reset code is invalid or expired.",
                StatusCodes.Status400BadRequest);
        }
    }
}
