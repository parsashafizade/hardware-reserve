using AutoMapper;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.Errors;
using FinalMvcApp.Mappings;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

public class AuthServiceRefreshTokenTests
{
    [Fact]
    public void RefreshTokenConfiguration_RevokedAt_IsConcurrencyToken()
    {
        using var dbContext = TestDbFactory.Create();

        var entityType = dbContext.Model.FindEntityType(typeof(RefreshToken));
        var revokedAt = entityType?.FindProperty(nameof(RefreshToken.RevokedAt));

        Assert.NotNull(revokedAt);
        Assert.True(revokedAt.IsConcurrencyToken);
    }

    [Fact]
    public async Task RefreshAsync_RotatesRefreshToken_AndRevokesPreviousToken()
    {
        await using var dbContext = TestDbFactory.Create();

        var user = new User
        {
            FullName = "Refresh User",
            Email = "refresh@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.SaveChangesAsync();

        var originalToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = "original-refresh-token",
            ExpiresAt = DateTime.UtcNow.AddDays(1),
            CreatedAt = DateTime.UtcNow,
            CreatedByIp = "127.0.0.1"
        };

        await dbContext.RefreshTokens.AddAsync(originalToken);
        await dbContext.SaveChangesAsync();

        var service = BuildAuthService(dbContext);

        var response = await service.RefreshAsync(
            new RefreshTokenRequestDto
            {
                RefreshToken = originalToken.Token
            },
            "127.0.0.1");

        Assert.NotNull(response.AccessToken);
        Assert.NotEqual(originalToken.Token, response.RefreshToken);
        Assert.Equal(user.Id, response.User.Id);

        var tokens = await dbContext.RefreshTokens
            .Where(token => token.UserId == user.Id)
            .OrderBy(token => token.CreatedAt)
            .ToListAsync();

        Assert.Equal(2, tokens.Count);
        Assert.NotNull(tokens[0].RevokedAt);
        Assert.Null(tokens[1].RevokedAt);
        Assert.Equal(response.RefreshToken, tokens[1].Token);
    }

    [Fact]
    public async Task RefreshAsync_ConcurrencyConflict_ReturnsInvalidRefreshToken()
    {
        await using var dbContext = TestDbFactory.Create();
        var token = CreateActiveRefreshToken();
        var service = BuildAuthService(
            dbContext,
            new ConcurrencyThrowingRefreshTokenRepository(token));

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.RefreshAsync(
                new RefreshTokenRequestDto
                {
                    RefreshToken = token.Token
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.InvalidRefreshToken, exception.Code);
        Assert.Equal(StatusCodes.Status401Unauthorized, exception.StatusCode);
    }

    [Fact]
    public async Task LogoutAsync_ConcurrencyConflict_RemainsIdempotent()
    {
        await using var dbContext = TestDbFactory.Create();
        var token = CreateActiveRefreshToken();
        var service = BuildAuthService(
            dbContext,
            new ConcurrencyThrowingRefreshTokenRepository(token));

        await service.LogoutAsync(
            new LogoutRequestDto
            {
                RefreshToken = token.Token
            });
    }

    private static AuthService BuildAuthService(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        IRefreshTokenRepository? refreshTokenRepository = null)
    {
        var mapper = new MapperConfiguration(
            config => config.AddProfile<MappingProfile>(),
            NullLoggerFactory.Instance)
            .CreateMapper();

        var jwtSettings =
            Microsoft.Extensions.Options.Options.Create(
                new JwtSettings
                {
                    Issuer = "TestIssuer",
                    Audience = "TestAudience",
                    Secret = "THIS_IS_A_TEST_SECRET_WITH_MORE_THAN_32_CHARS",
                    AccessTokenMinutes = 30,
                    RefreshTokenDays = 7
                });

        return new AuthService(
            new UserRepository(dbContext),
            refreshTokenRepository ?? new RefreshTokenRepository(dbContext),
            new PasswordResetTokenRepository(dbContext),
            new BCryptPasswordHasher(),
            new JwtTokenService(jwtSettings),
            new NoOpCaptchaService(),
            new NoOpEmailSender(),
            new NoOpEmailVerificationService(),
            new NoOpPasswordResetCodeService(),
            jwtSettings,
            mapper);
    }

    private static RefreshToken CreateActiveRefreshToken()
    {
        var user = new User
        {
            Id = 42,
            FullName = "Concurrent Refresh User",
            Email = "concurrent-refresh@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = true
        };

        return new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            User = user,
            Token = "concurrent-refresh-token",
            ExpiresAt = DateTime.UtcNow.AddDays(1),
            CreatedAt = DateTime.UtcNow,
            CreatedByIp = "127.0.0.1"
        };
    }

    private sealed class ConcurrencyThrowingRefreshTokenRepository
        : IRefreshTokenRepository
    {
        private readonly RefreshToken _refreshToken;

        public ConcurrencyThrowingRefreshTokenRepository(
            RefreshToken refreshToken)
        {
            _refreshToken = refreshToken;
        }

        public Task AddAsync(
            RefreshToken refreshToken,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }

        public Task<RefreshToken?> GetByTokenAsync(
            string token,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult<RefreshToken?>(
                token == _refreshToken.Token ? _refreshToken : null);
        }

        public Task<IReadOnlyList<RefreshToken>> GetByUserIdAsync(
            int userId,
            CancellationToken cancellationToken = default)
        {
            IReadOnlyList<RefreshToken> tokens = [_refreshToken];
            return Task.FromResult(tokens);
        }

        public void Update(RefreshToken refreshToken)
        {
        }

        public Task<int> SaveChangesAsync(
            CancellationToken cancellationToken = default)
        {
            return Task.FromException<int>(
                new DbUpdateConcurrencyException());
        }
    }

    private sealed class NoOpCaptchaService : ICaptchaService
    {
        public CaptchaChallengeResponseDto CreateChallenge()
        {
            return new CaptchaChallengeResponseDto
            {
                CaptchaId = Guid.NewGuid().ToString("N"),
                A = 1,
                B = 1
            };
        }

        public void ValidateAndConsume(
            string captchaId,
            int captchaAnswer)
        {
            _ = captchaId;
            _ = captchaAnswer;
        }
    }

    private sealed class NoOpEmailSender : IEmailSender
    {
        public Task SendPasswordResetCodeAsync(
            string toEmail,
            string fullName,
            string code,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }

        public Task SendEmailVerificationCodeAsync(
            string toEmail,
            string fullName,
            string code,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }

        public Task SendCurrentEmailChangeCodeAsync(
            string toEmail,
            string fullName,
            string code,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }

        public Task SendNewEmailChangeCodeAsync(
            string toEmail,
            string fullName,
            string code,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }
    }

    private sealed class NoOpEmailVerificationService
        : IEmailVerificationService
    {
        public Task<EmailVerificationIssueResult?> IssueCodeAsync(
            int userId,
            bool enforceResendCooldown,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult<EmailVerificationIssueResult?>(
                new EmailVerificationIssueResult(
                    "000000",
                    DateTime.UtcNow.AddMinutes(10)));
        }

        public Task ValidateAndConsumeAsync(
            int userId,
            string code,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }
    }

    private sealed class NoOpPasswordResetCodeService
        : IPasswordResetCodeService
    {
        public Task<PasswordResetCodeIssueResult?> IssueCodeAsync(
            int userId,
            bool enforceCooldown,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult<PasswordResetCodeIssueResult?>(null);
        }

        public Task ValidateAndConsumeAsync(
            int userId,
            string code,
            CancellationToken cancellationToken = default)
        {
            return Task.CompletedTask;
        }
    }
}
