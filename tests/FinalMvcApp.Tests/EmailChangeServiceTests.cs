using AutoMapper;
using FinalMvcApp.Data;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.DTOs.Profile;
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

namespace FinalMvcApp.Tests;

public class EmailChangeServiceTests
{
    private const string HmacKey =
        "TEST_EMAIL_CHANGE_HMAC_KEY_AT_LEAST_32_CHARS";

    [Fact]
    public async Task VerifyBothCodes_ChangesEmailAndRotatesSession()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var oldRefreshToken = await AddRefreshTokenAsync(dbContext, user.Id);
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);

        var status = await service.StartAsync(
            user.Id,
            new StartEmailChangeRequestDto
            {
                NewEmail = "  NEW.ADDRESS@EXAMPLE.COM  "
            });

        var pending = await dbContext.PendingEmailChanges.SingleAsync();
        Assert.Equal("owner@example.com", user.Email);
        Assert.Equal("new.address@example.com", status.NewEmail);
        Assert.Equal(64, pending.CurrentCodeHash.Length);
        Assert.Equal(64, pending.NewCodeHash.Length);
        Assert.NotEqual(emailSender.CurrentCode, pending.CurrentCodeHash);
        Assert.NotEqual(emailSender.NewCode, pending.NewCodeHash);

        var firstVerification = await service.VerifyCurrentAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.CurrentCode
            },
            "127.0.0.1");

        Assert.False(firstVerification.Completed);
        Assert.True(firstVerification.Status?.CurrentEmailVerified);
        Assert.Equal("owner@example.com", user.Email);

        var completed = await service.VerifyNewAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.NewCode
            },
            "127.0.0.2");

        Assert.True(completed.Completed);
        var authentication = Assert.IsType<AuthResponseDto>(
            completed.Authentication);
        Assert.Equal("new.address@example.com", user.Email);
        Assert.True(user.IsEmailVerified);
        Assert.NotNull(user.EmailVerifiedAt);
        Assert.Equal(user.Email, authentication.User.Email);
        Assert.NotNull(pending.CompletedAt);
        Assert.NotNull(oldRefreshToken.RevokedAt);

        var refreshTokens = await dbContext.RefreshTokens
            .Where(token => token.UserId == user.Id)
            .ToListAsync();

        Assert.Single(refreshTokens, token => token.RevokedAt is null);
        Assert.Contains(
            refreshTokens,
            token => token.Token == authentication.RefreshToken
                     && token.RevokedAt is null);

        var replay = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyNewAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.NewCode
                },
                "127.0.0.3"));

        Assert.Equal(ApiErrorCodes.EmailChangeInvalid, replay.Code);
    }

    [Fact]
    public async Task Start_RejectsCurrentEmailAfterNormalization()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var service = CreateService(dbContext, new RecordingEmailSender());

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.StartAsync(
                user.Id,
                new StartEmailChangeRequestDto
                {
                    NewEmail = " OWNER@EXAMPLE.COM "
                }));

        Assert.Equal(ApiErrorCodes.EmailChangeSameEmail, exception.Code);
        Assert.Empty(dbContext.PendingEmailChanges);
    }

    [Fact]
    public async Task Start_RejectsEmailAlreadyUsedByAnotherUser()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        _ = await AddUserAsync(dbContext, "taken@example.com");
        var service = CreateService(dbContext, new RecordingEmailSender());

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.StartAsync(
                user.Id,
                new StartEmailChangeRequestDto
                {
                    NewEmail = "TAKEN@example.com"
                }));

        Assert.Equal(ApiErrorCodes.EmailChangeEmailInUse, exception.Code);
        Assert.Equal("owner@example.com", user.Email);
    }

    [Fact]
    public async Task Codes_ArePurposeBoundAndCannotBeInterchanged()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "new@example.com");

        var currentException = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.NewCode
                },
                "127.0.0.1"));
        var newException = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyNewAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.CurrentCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeCodeInvalid, currentException.Code);
        Assert.Equal(ApiErrorCodes.EmailChangeCodeInvalid, newException.Code);
        Assert.Equal("owner@example.com", user.Email);

        await service.VerifyCurrentAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.CurrentCode
            },
            "127.0.0.1");
        var completed = await service.VerifyNewAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.NewCode
            },
            "127.0.0.1");

        Assert.True(completed.Completed);
    }

    [Fact]
    public async Task ExpiredCodesAreRejectedAndOriginalEmailRemainsActive()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "new@example.com");

        var pending = await dbContext.PendingEmailChanges.SingleAsync();
        pending.CurrentCodeExpiresAt = DateTime.UtcNow.AddSeconds(-1);
        pending.NewCodeExpiresAt = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();

        var currentException = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.CurrentCode
                },
                "127.0.0.1"));
        var newException = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyNewAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.NewCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeCodeInvalid, currentException.Code);
        Assert.Equal(ApiErrorCodes.EmailChangeCodeInvalid, newException.Code);
        Assert.NotNull(pending.CurrentCodeUsedAt);
        Assert.NotNull(pending.NewCodeUsedAt);
        Assert.Equal("owner@example.com", user.Email);
    }

    [Fact]
    public async Task VerifiedCodeCannotBeReused()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "new@example.com");

        await service.VerifyCurrentAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.CurrentCode
            },
            "127.0.0.1");

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.CurrentCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeAlreadyVerified, exception.Code);
        Assert.Equal("owner@example.com", user.Email);
    }

    [Fact]
    public async Task ResendInvalidatesPreviousCodeForThatDestination()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(
            dbContext,
            emailSender,
            resendCooldownSeconds: 0);
        await StartAsync(service, user.Id, "new@example.com");
        var firstCode = emailSender.CurrentCode;

        await service.ResendCurrentAsync(user.Id);
        var replacementCode = emailSender.CurrentCode;

        Assert.NotEqual(firstCode, replacementCode);
        Assert.Single(await dbContext.PendingEmailChanges.ToListAsync());

        var oldCodeException = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = firstCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeCodeInvalid, oldCodeException.Code);

        var response = await service.VerifyCurrentAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = replacementCode
            },
            "127.0.0.1");

        Assert.False(response.Completed);
        Assert.True(response.Status?.CurrentEmailVerified);
    }

    [Fact]
    public async Task OneVerifiedSideDoesNotChangeEmail()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "new@example.com");

        var response = await service.VerifyNewAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.NewCode
            },
            "127.0.0.1");

        Assert.False(response.Completed);
        Assert.True(response.Status?.NewEmailVerified);
        Assert.False(response.Status?.CurrentEmailVerified);
        Assert.Equal("owner@example.com", user.Email);
        Assert.Empty(dbContext.RefreshTokens);
    }

    [Fact]
    public async Task MaximumFailedAttemptsInvalidatesOnlyTargetCode()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        const int maxAttempts = 3;
        var service = CreateService(
            dbContext,
            emailSender,
            maxAttempts: maxAttempts);
        await StartAsync(service, user.Id, "new@example.com");
        var wrongCode = DifferentCode(emailSender.CurrentCode);

        for (var attempt = 0; attempt < maxAttempts; attempt++)
        {
            await Assert.ThrowsAsync<ApiException>(
                () => service.VerifyCurrentAsync(
                    user.Id,
                    new VerifyEmailChangeCodeRequestDto
                    {
                        Code = wrongCode
                    },
                    "127.0.0.1"));
        }

        var pending = await dbContext.PendingEmailChanges.SingleAsync();
        Assert.Equal(maxAttempts, pending.CurrentAttemptCount);
        Assert.NotNull(pending.CurrentCodeUsedAt);
        Assert.Null(pending.NewCodeUsedAt);

        await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.CurrentCode
                },
                "127.0.0.1"));

        var newSide = await service.VerifyNewAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.NewCode
            },
            "127.0.0.1");
        Assert.False(newSide.Completed);
        Assert.True(newSide.Status?.NewEmailVerified);
        Assert.Equal("owner@example.com", user.Email);
    }

    [Fact]
    public async Task StartingReplacementInvalidatesBothPreviousCodes()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "first@example.com");
        var oldCurrentCode = emailSender.CurrentCode;
        var oldNewCode = emailSender.NewCode;

        await StartAsync(service, user.Id, "second@example.com");

        await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = oldCurrentCode
                },
                "127.0.0.1"));
        await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyNewAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = oldNewCode
                },
                "127.0.0.1"));

        var pending = await dbContext.PendingEmailChanges.SingleAsync();
        Assert.Equal("second@example.com", pending.NewEmail);
        Assert.Equal("owner@example.com", user.Email);
    }

    [Fact]
    public async Task FinalUniquenessConflictLeavesOriginalEmailUnchanged()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "contested@example.com");
        await service.VerifyCurrentAsync(
            user.Id,
            new VerifyEmailChangeCodeRequestDto
            {
                Code = emailSender.CurrentCode
            },
            "127.0.0.1");

        _ = await AddUserAsync(dbContext, "contested@example.com");

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyNewAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.NewCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeEmailInUse, exception.Code);
        Assert.Equal("owner@example.com", user.Email);
        Assert.Empty(
            await dbContext.RefreshTokens
                .Where(token => token.UserId == user.Id)
                .ToListAsync());

        dbContext.ChangeTracker.Clear();
        var persistedUser = await dbContext.Users.FindAsync(user.Id);
        var persistedRequest = await dbContext.PendingEmailChanges.SingleAsync();
        Assert.Equal("owner@example.com", persistedUser?.Email);
        Assert.Null(persistedRequest.NewEmailVerifiedAt);
        Assert.Null(persistedRequest.CompletedAt);
    }

    [Fact]
    public async Task CancelledRequestCannotBeVerifiedAndLeavesEmailUnchanged()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await AddUserAsync(dbContext, "owner@example.com");
        var emailSender = new RecordingEmailSender();
        var service = CreateService(dbContext, emailSender);
        await StartAsync(service, user.Id, "new@example.com");

        await service.CancelAsync(user.Id);

        var exception = await Assert.ThrowsAsync<ApiException>(
            () => service.VerifyCurrentAsync(
                user.Id,
                new VerifyEmailChangeCodeRequestDto
                {
                    Code = emailSender.CurrentCode
                },
                "127.0.0.1"));

        Assert.Equal(ApiErrorCodes.EmailChangeInvalid, exception.Code);
        Assert.Equal("owner@example.com", user.Email);
        Assert.Null(await service.GetStatusAsync(user.Id));
    }

    private static EmailChangeService CreateService(
        ApplicationDbContext dbContext,
        RecordingEmailSender emailSender,
        int maxAttempts = 5,
        int resendCooldownSeconds = 60)
    {
        return new EmailChangeService(
            new PendingEmailChangeRepository(dbContext),
            new UserRepository(dbContext),
            new RefreshTokenRepository(dbContext),
            emailSender,
            CreateAuthService(dbContext, emailSender),
            Microsoft.Extensions.Options.Options.Create(
                new EmailVerificationSettings
                {
                    HmacKey = HmacKey,
                    CodeLifetimeMinutes = 10,
                    ResendCooldownSeconds = resendCooldownSeconds,
                    MaxAttempts = maxAttempts
                }));
    }

    private static AuthService CreateAuthService(
        ApplicationDbContext dbContext,
        IEmailSender emailSender)
    {
        var jwtSettings = Microsoft.Extensions.Options.Options.Create(
            new JwtSettings
            {
                Issuer = "EmailChangeTests",
                Audience = "EmailChangeTests",
                Secret = "EMAIL_CHANGE_TEST_JWT_SECRET_AT_LEAST_32_CHARS",
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
            emailSender,
            new NoOpEmailVerificationService(),
            new NoOpPasswordResetCodeService(),
            jwtSettings,
            mapper);
    }

    private static async Task StartAsync(
        EmailChangeService service,
        int userId,
        string newEmail)
    {
        await service.StartAsync(
            userId,
            new StartEmailChangeRequestDto
            {
                NewEmail = newEmail
            });
    }

    private static async Task<User> AddUserAsync(
        ApplicationDbContext dbContext,
        string email)
    {
        var user = new User
        {
            FullName = "Email Change Test User",
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Password123!"),
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            IsEmailVerified = true,
            EmailVerifiedAt = DateTime.UtcNow
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.SaveChangesAsync();
        return user;
    }

    private static async Task<RefreshToken> AddRefreshTokenAsync(
        ApplicationDbContext dbContext,
        int userId)
    {
        var token = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Token = $"old-token-{Guid.NewGuid():N}",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(1),
            CreatedByIp = "127.0.0.1"
        };

        await dbContext.RefreshTokens.AddAsync(token);
        await dbContext.SaveChangesAsync();
        return token;
    }

    private static string DifferentCode(string code)
    {
        return code == "000000" ? "000001" : "000000";
    }

    private sealed class RecordingEmailSender : IEmailSender
    {
        public string CurrentCode { get; private set; } = string.Empty;

        public string NewCode { get; private set; } = string.Empty;

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
            CurrentCode = code;
            return Task.CompletedTask;
        }

        public Task SendNewEmailChangeCodeAsync(
            string toEmail,
            string fullName,
            string code,
            DateTime expiresAtUtc,
            CancellationToken cancellationToken = default)
        {
            NewCode = code;
            return Task.CompletedTask;
        }
    }

    private sealed class NoOpCaptchaService : ICaptchaService
    {
        public CaptchaChallengeResponseDto CreateChallenge()
        {
            return new CaptchaChallengeResponseDto
            {
                CaptchaId = "unused",
                A = 1,
                B = 1
            };
        }

        public void ValidateAndConsume(string captchaId, int captchaAnswer)
        {
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
            return Task.FromResult<EmailVerificationIssueResult?>(null);
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
