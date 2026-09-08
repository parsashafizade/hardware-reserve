using AutoMapper;
using FinalMvcApp.Data;
using FinalMvcApp.Data.Seed;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.Errors;
using FinalMvcApp.Mappings;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace FinalMvcApp.Tests;

public class AuthenticationHardeningTests
{
    private const string HmacKey =
        "TEST_HMAC_KEY_WITH_AT_LEAST_32_CHARACTERS";

    [Fact]
    public async Task EmailVerification_Success_VerifiesUserAndConsumesCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var verificationService = CreateEmailVerificationService(dbContext);
        var issued = Assert.IsType<EmailVerificationIssueResult>(
            await verificationService.IssueCodeAsync(
                user.Id,
                enforceResendCooldown: false));
        Assert.Matches("^[0-9]{6}$", issued.Code);
        var authService = BuildAuthService(
            dbContext,
            verificationService,
            CreatePasswordResetCodeService(dbContext));

        var response = await authService.VerifyEmailAsync(
            new VerifyEmailRequestDto
            {
                Email = user.Email.ToUpperInvariant(),
                Code = issued.Code
            },
            "127.0.0.1");

        Assert.Equal(user.Id, response.User.Id);
        Assert.True(user.IsEmailVerified);
        Assert.NotNull(user.EmailVerifiedAt);

        var persistedCode = await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id);

        Assert.NotNull(persistedCode.UsedAt);
        Assert.NotEqual(issued.Code, persistedCode.CodeHash);
        Assert.Equal(64, persistedCode.CodeHash.Length);
    }

    [Fact]
    public async Task EmailVerification_ResendCooldown_DoesNotIssueAnotherCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var service = CreateEmailVerificationService(dbContext);
        _ = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var originalHash = (await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id))
            .CodeHash;

        var resend = await service.IssueCodeAsync(user.Id, true);

        Assert.Null(resend);
        var persistedCode = await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id);
        Assert.Equal(originalHash, persistedCode.CodeHash);
    }

    [Fact]
    public async Task EmailVerification_InvalidCode_ReturnsStableErrorCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var service = CreateEmailVerificationService(dbContext);
        var issued = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var wrongCode = DifferentCode(issued.Code);

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, wrongCode));

        Assert.Equal(
            ApiErrorCodes.EmailVerificationCodeInvalid,
            exception.Code);
    }

    [Fact]
    public async Task EmailVerification_ExpiredCode_IsConsumedAndRejected()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var service = CreateEmailVerificationService(dbContext);
        var issued = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var persistedCode = await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id);

        persistedCode.ExpiresAt = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, issued.Code));

        Assert.Equal(
            ApiErrorCodes.EmailVerificationCodeInvalid,
            exception.Code);
        Assert.NotNull(persistedCode.UsedAt);
    }

    [Fact]
    public async Task EmailVerification_ConsumedCode_CannotBeReused()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var service = CreateEmailVerificationService(dbContext);
        var issued = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));

        await service.ValidateAndConsumeAsync(user.Id, issued.Code);

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, issued.Code));

        Assert.Equal(
            ApiErrorCodes.EmailVerificationCodeInvalid,
            exception.Code);
    }

    [Fact]
    public async Task EmailVerification_Resend_ReplacesPreviousCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        var service = CreateEmailVerificationService(dbContext);
        var first = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var persistedCode = await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id);

        persistedCode.CreatedAt = DateTime.UtcNow.AddMinutes(-2);
        await dbContext.SaveChangesAsync();

        var second = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, true));

        Assert.NotEqual(first.Code, second.Code);
        Assert.Single(await dbContext.EmailVerificationCodes.ToListAsync());

        await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, first.Code));

        await service.ValidateAndConsumeAsync(user.Id, second.Code);
    }

    [Fact]
    public async Task EmailVerification_MaxFailedAttempts_InvalidatesCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: false);
        const int maxAttempts = 3;
        var service = CreateEmailVerificationService(
            dbContext,
            maxAttempts: maxAttempts);
        var issued = Assert.IsType<EmailVerificationIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var wrongCode = DifferentCode(issued.Code);

        for (var attempt = 0; attempt < maxAttempts; attempt++)
        {
            await Assert.ThrowsAsync<ApiException>(
                () => service.ValidateAndConsumeAsync(user.Id, wrongCode));
        }

        var persistedCode = await dbContext.EmailVerificationCodes
            .SingleAsync(code => code.UserId == user.Id);

        Assert.Equal(maxAttempts, persistedCode.AttemptCount);
        Assert.NotNull(persistedCode.UsedAt);

        await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, issued.Code));
    }

    [Fact]
    public async Task PasswordResetCode_SuccessThenReuse_IsRejected()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: true);
        var service = CreatePasswordResetCodeService(dbContext);
        var issued = Assert.IsType<PasswordResetCodeIssueResult>(
            await service.IssueCodeAsync(user.Id, false));

        await service.ValidateAndConsumeAsync(user.Id, issued.Code);

        var persistedCode = await dbContext.PasswordResetCodes
            .SingleAsync(code => code.UserId == user.Id);

        Assert.NotNull(persistedCode.UsedAt);
        Assert.NotEqual(issued.Code, persistedCode.CodeHash);

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, issued.Code));

        Assert.Equal(ApiErrorCodes.PasswordResetCodeInvalid, exception.Code);
    }

    [Fact]
    public async Task PasswordResetCode_InvalidAndExpiredCodes_AreRejected()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: true);
        var service = CreatePasswordResetCodeService(dbContext);
        var issued = Assert.IsType<PasswordResetCodeIssueResult>(
            await service.IssueCodeAsync(user.Id, false));

        var invalidException = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(
                user.Id,
                DifferentCode(issued.Code)));

        Assert.Equal(
            ApiErrorCodes.PasswordResetCodeInvalid,
            invalidException.Code);

        var persistedCode = await dbContext.PasswordResetCodes
            .SingleAsync(code => code.UserId == user.Id);

        persistedCode.ExpiresAt = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();

        var expiredException = await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, issued.Code));

        Assert.Equal(
            ApiErrorCodes.PasswordResetCodeInvalid,
            expiredException.Code);
        Assert.NotNull(persistedCode.UsedAt);
    }

    [Fact]
    public async Task PasswordResetCode_Resend_ReplacesPreviousCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: true);
        var service = CreatePasswordResetCodeService(dbContext);
        var first = Assert.IsType<PasswordResetCodeIssueResult>(
            await service.IssueCodeAsync(user.Id, false));
        var persistedCode = await dbContext.PasswordResetCodes
            .SingleAsync(code => code.UserId == user.Id);

        persistedCode.CreatedAt = DateTime.UtcNow.AddMinutes(-2);
        await dbContext.SaveChangesAsync();

        var second = Assert.IsType<PasswordResetCodeIssueResult>(
            await service.IssueCodeAsync(user.Id, true));

        Assert.NotEqual(first.Code, second.Code);
        Assert.Single(await dbContext.PasswordResetCodes.ToListAsync());

        await Assert.ThrowsAsync<ApiException>(
            () => service.ValidateAndConsumeAsync(user.Id, first.Code));

        await service.ValidateAndConsumeAsync(user.Id, second.Code);
    }

    [Fact]
    public async Task ResetPassword_ConsumesTokenAndRevokesPreviousSessions()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, isEmailVerified: true);
        var now = DateTime.UtcNow;
        var existingRefreshToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = "existing-active-refresh-token",
            ExpiresAt = now.AddDays(1),
            CreatedAt = now,
            CreatedByIp = "127.0.0.1"
        };

        await dbContext.RefreshTokens.AddAsync(existingRefreshToken);
        await dbContext.SaveChangesAsync();

        var resetCodeService = CreatePasswordResetCodeService(dbContext);
        var issuedCode = Assert.IsType<PasswordResetCodeIssueResult>(
            await resetCodeService.IssueCodeAsync(user.Id, false));
        var authService = BuildAuthService(
            dbContext,
            CreateEmailVerificationService(dbContext),
            resetCodeService);
        var verifiedCode = await authService.VerifyPasswordResetCodeAsync(
            new VerifyPasswordResetCodeRequestDto
            {
                Email = user.Email,
                Code = issuedCode.Code
            });

        var response = await authService.ResetPasswordAsync(
            new ResetPasswordRequestDto
            {
                Token = verifiedCode.ResetToken,
                NewPassword = "UpdatedPassword123!",
                ConfirmPassword = "UpdatedPassword123!"
            },
            "127.0.0.2");

        Assert.Equal(user.Id, response.User.Id);
        Assert.True(
            BCrypt.Net.BCrypt.Verify(
                "UpdatedPassword123!",
                user.PasswordHash));
        Assert.NotNull(existingRefreshToken.RevokedAt);
        Assert.Empty(await dbContext.PasswordResetTokens.ToListAsync());

        var refreshTokens = await dbContext.RefreshTokens
            .Where(token => token.UserId == user.Id)
            .ToListAsync();

        Assert.Single(refreshTokens, token => token.RevokedAt is null);
        Assert.Contains(
            refreshTokens,
            token => token.Token == response.RefreshToken
                     && token.RevokedAt is null);

        var reuseException = await Assert.ThrowsAsync<ApiException>(
            () => authService.ResetPasswordAsync(
                new ResetPasswordRequestDto
                {
                    Token = verifiedCode.ResetToken,
                    NewPassword = "AnotherPassword123!",
                    ConfirmPassword = "AnotherPassword123!"
                },
                "127.0.0.3"));

        Assert.Equal(
            ApiErrorCodes.PasswordResetTokenInvalid,
            reuseException.Code);
    }

    [Fact]
    public async Task Refresh_InvalidToken_ReturnsStableErrorCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var authService = BuildAuthService(
            dbContext,
            CreateEmailVerificationService(dbContext),
            CreatePasswordResetCodeService(dbContext));

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => authService.RefreshAsync(
                new RefreshTokenRequestDto
                {
                    RefreshToken = "missing-refresh-token"
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.InvalidRefreshToken, exception.Code);
        Assert.Equal(401, exception.StatusCode);
    }

    [Fact]
    public async Task Seeders_CreateLoginReadyVerifiedAccounts()
    {
        await using var dbContext = TestDbFactory.Create();

        await AdminSeeder.SeedAsync(dbContext);
        await DemoUserSeeder.SeedAsync(dbContext);

        var seededUsers = await dbContext.Users.ToListAsync();

        Assert.Equal(2, seededUsers.Count);
        Assert.All(seededUsers, user => Assert.True(user.IsEmailVerified));
        Assert.All(seededUsers, user => Assert.NotNull(user.EmailVerifiedAt));
    }

    [Fact]
    public async Task Seeders_RepairExistingUnverifiedSeedAccounts()
    {
        await using var dbContext = TestDbFactory.Create();
        var admin = new User
        {
            FullName = "Existing Admin",
            Email = "admin",
            PasswordHash = "hash",
            Role = UserRole.Admin,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = false
        };
        var demo = new User
        {
            FullName = "Existing Demo",
            Email = "demo@university.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = false
        };

        await dbContext.Users.AddRangeAsync(admin, demo);
        await dbContext.SaveChangesAsync();

        await AdminSeeder.SeedAsync(dbContext);
        await DemoUserSeeder.SeedAsync(dbContext);

        Assert.True(admin.IsEmailVerified);
        Assert.NotNull(admin.EmailVerifiedAt);
        Assert.True(demo.IsEmailVerified);
        Assert.NotNull(demo.EmailVerifiedAt);
        Assert.Equal(2, await dbContext.Users.CountAsync());
    }

    private static EmailVerificationService CreateEmailVerificationService(
        ApplicationDbContext dbContext,
        int maxAttempts = 5)
    {
        return new EmailVerificationService(
            new EmailVerificationCodeRepository(dbContext),
            Microsoft.Extensions.Options.Options.Create(
                new EmailVerificationSettings
                {
                    HmacKey = HmacKey,
                    CodeLifetimeMinutes = 10,
                    ResendCooldownSeconds = 60,
                    MaxAttempts = maxAttempts
                }));
    }

    private static PasswordResetCodeService CreatePasswordResetCodeService(
        ApplicationDbContext dbContext,
        int maxAttempts = 5)
    {
        return new PasswordResetCodeService(
            new PasswordResetCodeRepository(dbContext),
            Microsoft.Extensions.Options.Options.Create(
                new PasswordResetSettings
                {
                    HmacKey = HmacKey,
                    CodeLifetimeMinutes = 10,
                    ResendCooldownSeconds = 60,
                    MaxAttempts = maxAttempts
                }));
    }

    private static AuthService BuildAuthService(
        ApplicationDbContext dbContext,
        IEmailVerificationService emailVerificationService,
        IPasswordResetCodeService passwordResetCodeService)
    {
        var jwtSettings = Microsoft.Extensions.Options.Options.Create(
            new JwtSettings
            {
                Issuer = "TestIssuer",
                Audience = "TestAudience",
                Secret = "THIS_IS_A_TEST_SECRET_WITH_MORE_THAN_32_CHARS",
                AccessTokenMinutes = 30,
                RefreshTokenDays = 7
            });
        var mapper = new MapperConfiguration(
            configuration => configuration.AddProfile<MappingProfile>(),
            NullLoggerFactory.Instance)
            .CreateMapper();

        return new AuthService(
            new UserRepository(dbContext),
            new RefreshTokenRepository(dbContext),
            new PasswordResetTokenRepository(dbContext),
            new BCryptPasswordHasher(),
            new JwtTokenService(jwtSettings),
            new NoOpCaptchaService(),
            new NoOpEmailSender(),
            emailVerificationService,
            passwordResetCodeService,
            jwtSettings,
            mapper);
    }

    private static async Task<User> AddUserAsync(
        ApplicationDbContext dbContext,
        bool isEmailVerified)
    {
        var user = new User
        {
            FullName = "Authentication Test User",
            Email = $"auth-{Guid.NewGuid():N}@test.local",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = isEmailVerified,
            EmailVerifiedAt = isEmailVerified ? DateTime.UtcNow : null
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.SaveChangesAsync();

        return user;
    }

    private static string DifferentCode(string code)
    {
        return code == "000000" ? "000001" : "000000";
    }

    private sealed class NoOpCaptchaService : ICaptchaService
    {
        public CaptchaChallengeResponseDto CreateChallenge()
        {
            return new CaptchaChallengeResponseDto
            {
                CaptchaId = "test-captcha",
                A = 1,
                B = 1
            };
        }

        public void ValidateAndConsume(string captchaId, int captchaAnswer)
        {
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
}
