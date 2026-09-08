using System.Security.Claims;
using System.Text.Json;
using FinalMvcApp.Controllers;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Validation.Admin;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

public class Phase2AdminExperienceTests
{
    private static readonly DateTime NowUtc = new(2026, 8, 23, 10, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task AdminCreation_NormalizesHashesVerifiesAuditsAndCanAuthenticate()
    {
        await using var dbContext = TestDbFactory.Create();
        var actingAdmin = await AddUserAsync(dbContext, "actor@test.local", UserRole.Admin);
        var service = BuildControlService(dbContext);
        const string password = "Phase2-Strong-Password";

        var response = await service.CreateAdminAsync(actingAdmin.Id, new CreateAdminAccountDto
        {
            FullName = "  Second Admin  ",
            Email = "  SECOND.ADMIN@TEST.LOCAL  ",
            Password = password
        });

        var created = await dbContext.Users.SingleAsync(user => user.Id == response.Id);
        Assert.Equal("Second Admin", created.FullName);
        Assert.Equal("second.admin@test.local", created.Email);
        Assert.Equal(UserRole.Admin, created.Role);
        Assert.True(created.IsEmailVerified);
        Assert.Equal(NowUtc, created.EmailVerifiedAt);
        Assert.NotEqual(password, created.PasswordHash);
        Assert.True(new BCryptPasswordHasher().VerifyPassword(password, created.PasswordHash));

        var serialized = JsonSerializer.Serialize(response);
        Assert.DoesNotContain(password, serialized);
        Assert.DoesNotContain("password", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.Null(typeof(AdminUserDto).GetProperty("PasswordHash"));

        var audit = Assert.Single(dbContext.AdminAuditEvents);
        Assert.Equal(actingAdmin.Id, audit.AdminUserId);
        Assert.Equal(AdminAuditAction.AdminAccountCreated, audit.Action);
        Assert.Equal(created.Id.ToString(), audit.EntityId);
        Assert.DoesNotContain(password, audit.Details ?? string.Empty);
        Assert.DoesNotContain(created.PasswordHash, audit.Details ?? string.Empty);

        var authenticated = await BuildAuthService(dbContext).LoginAsync(
            new LoginRequestDto
            {
                Identifier = " SECOND.ADMIN@TEST.LOCAL ",
                Password = password,
                CaptchaId = "accepted",
                CaptchaAnswer = 2
            },
            "127.0.0.1");
        Assert.Equal(created.Id, authenticated.User.Id);
        Assert.Equal(UserRole.Admin.ToString(), authenticated.User.Role);
    }

    [Fact]
    public async Task AdminCreation_DuplicateNormalizedEmailIsRejected()
    {
        await using var dbContext = TestDbFactory.Create();
        var actingAdmin = await AddUserAsync(dbContext, "actor@test.local", UserRole.Admin);
        _ = await AddUserAsync(dbContext, "existing@test.local", UserRole.User);
        var service = BuildControlService(dbContext);

        var exception = await Assert.ThrowsAsync<ApiException>(() => service.CreateAdminAsync(
            actingAdmin.Id,
            new CreateAdminAccountDto
            {
                FullName = "Duplicate",
                Email = " EXISTING@TEST.LOCAL ",
                Password = "Password-123"
            }));

        Assert.Equal(ApiErrorCodes.EmailAlreadyExists, exception.Code);
        Assert.Equal(2, await dbContext.Users.CountAsync());
        Assert.Empty(dbContext.AdminAuditEvents);
    }

    [Fact]
    public void AdminCreation_UsesTheExistingPasswordLengthPolicy()
    {
        var validator = new CreateAdminAccountDtoValidator();

        Assert.False(validator.Validate(new CreateAdminAccountDto
        {
            FullName = "Admin",
            Email = "admin@test.local",
            Password = "short"
        }).IsValid);
        Assert.True(validator.Validate(new CreateAdminAccountDto
        {
            FullName = "Admin",
            Email = "admin@test.local",
            Password = "12345678"
        }).IsValid);
    }

    [Theory]
    [InlineData(typeof(AdminOperationsController))]
    [InlineData(typeof(DashboardController))]
    public async Task Phase2AdminEndpoints_DenyAnonymousAndUsersButAllowAdmins(Type controllerType)
    {
        var services = new ServiceCollection()
            .AddLogging()
            .AddAuthorization()
            .BuildServiceProvider();
        var policyProvider = services.GetRequiredService<IAuthorizationPolicyProvider>();
        var authorizeData = controllerType
            .GetCustomAttributes(inherit: true)
            .OfType<IAuthorizeData>()
            .ToArray();
        var policy = await AuthorizationPolicy.CombineAsync(policyProvider, authorizeData);
        Assert.NotNull(policy);
        var authorization = services.GetRequiredService<IAuthorizationService>();

        Assert.False((await authorization.AuthorizeAsync(
            new ClaimsPrincipal(new ClaimsIdentity()),
            null,
            policy!)).Succeeded);
        Assert.False((await authorization.AuthorizeAsync(
            Principal(UserRole.User),
            null,
            policy)).Succeeded);
        Assert.True((await authorization.AuthorizeAsync(
            Principal(UserRole.Admin),
            null,
            policy)).Succeeded);
    }

    [Fact]
    public async Task DashboardActionCounts_UseAssignmentAndSupportSourceOfTruth()
    {
        await using var dbContext = TestDbFactory.Create();
        var admin = await AddUserAsync(dbContext, "admin@test.local", UserRole.Admin);
        var user = await AddUserAsync(dbContext, "user@test.local", UserRole.User);
        var server = await AddServerAsync(dbContext);

        dbContext.Reservations.AddRange(
            Reservation(user.Id, server.Id, ReservationStatus.Paid, NowUtc.AddHours(4)),
            Reservation(user.Id, server.Id, ReservationStatus.Paid, NowUtc.AddHours(5), ip: "203.0.113.1"),
            Reservation(user.Id, server.Id, ReservationStatus.Paid, NowUtc.AddHours(6), username: "operator"),
            Reservation(user.Id, server.Id, ReservationStatus.Paid, NowUtc.AddHours(7), "203.0.113.2", "assigned", "secret"),
            Reservation(user.Id, server.Id, ReservationStatus.Cancelled, NowUtc.AddHours(8)),
            Reservation(user.Id, server.Id, ReservationStatus.PendingPayment, NowUtc.AddHours(9)),
            Reservation(user.Id, server.Id, ReservationStatus.Paid, NowUtc.AddHours(-1)));

        dbContext.SupportConversations.AddRange(
            Conversation(user.Id, SupportConversationStatus.WAITING_FOR_ADMIN, 0),
            Conversation(user.Id, SupportConversationStatus.ADMIN_ACTIVE, 2, admin.Id),
            Conversation(user.Id, SupportConversationStatus.ADMIN_ACTIVE, 0, admin.Id),
            Conversation(user.Id, SupportConversationStatus.RESOLVED, 3, admin.Id));
        await dbContext.SaveChangesAsync();

        var counts = await new AdminControlRepository(dbContext)
            .GetOperationalCountsAsync(NowUtc);

        Assert.Equal(3, counts.PendingAssignmentReservations);
        Assert.Equal(2, counts.SupportAttentionConversations);
        var dashboard = await BuildAdminService(dbContext).GetDashboardStatsAsync();
        Assert.Equal(3, dashboard.PendingAssignmentReservations);
        Assert.Equal(2, dashboard.SupportAttentionConversations);

        foreach (var reservation in dbContext.Reservations.Where(item =>
                     item.Status == ReservationStatus.Paid && item.EndTime > NowUtc))
        {
            reservation.AssignedIp ??= "203.0.113.50";
            reservation.AssignedUsername ??= "assigned";
            reservation.AssignedPassword ??= "secret";
        }
        foreach (var conversation in dbContext.SupportConversations)
        {
            conversation.Status = SupportConversationStatus.CLOSED;
            conversation.ReadState.AdminUnreadCount = 0;
        }
        await dbContext.SaveChangesAsync();

        var zeroCounts = await new AdminControlRepository(dbContext)
            .GetOperationalCountsAsync(NowUtc);
        Assert.Equal(0, zeroCounts.PendingAssignmentReservations);
        Assert.Equal(0, zeroCounts.SupportAttentionConversations);
    }

    private static ClaimsPrincipal Principal(UserRole role) => new(
        new ClaimsIdentity(
            [new Claim(ClaimTypes.Role, role.ToString())],
            "Phase2Test"));

    private static AdminControlService BuildControlService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var notifications = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            new FixedTimeProvider(NowUtc),
            NullLogger<UserNotificationService>.Instance);
        return new AdminControlService(
            new AdminControlRepository(dbContext),
            new ServerRepository(dbContext),
            new ReservationRepository(dbContext),
            notifications,
            new BCryptPasswordHasher(),
            new FixedTimeProvider(NowUtc));
    }

    private static AuthService BuildAuthService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var jwtOptions = Microsoft.Extensions.Options.Options.Create(new JwtSettings
        {
            Issuer = "Phase2Tests",
            Audience = "Phase2Tests",
            Secret = "PHASE2_TEST_SECRET_WITH_MORE_THAN_32_CHARACTERS",
            AccessTokenMinutes = 30,
            RefreshTokenDays = 7
        });
        return new AuthService(
            new UserRepository(dbContext),
            new RefreshTokenRepository(dbContext),
            new PasswordResetTokenRepository(dbContext),
            new BCryptPasswordHasher(),
            new JwtTokenService(jwtOptions),
            new AcceptingCaptchaService(),
            new NoOpEmailSender(),
            new NoOpEmailVerificationService(),
            new NoOpPasswordResetCodeService(),
            jwtOptions,
            SupportTestFactory.CreateMapper());
    }

    private static AdminService BuildAdminService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var reservationRepository = new ReservationRepository(dbContext);
        var notifications = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            new RecordingUserNotificationRealtimeNotifier(),
            new FixedTimeProvider(NowUtc),
            NullLogger<UserNotificationService>.Instance);
        return new AdminService(
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            reservationRepository,
            new PaymentRepository(dbContext),
            new ServiceDetailsNotificationService(
                reservationRepository,
                notifications,
                new FixedTimeProvider(NowUtc),
                NullLogger<ServiceDetailsNotificationService>.Instance),
            new AdminControlRepository(dbContext),
            new FixedTimeProvider(NowUtc));
    }

    private static async Task<User> AddUserAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        string email,
        UserRole role)
    {
        var user = new User
        {
            FullName = email,
            Email = email,
            PasswordHash = "unused",
            Role = role,
            IsEmailVerified = true,
            EmailVerifiedAt = NowUtc,
            CreatedAt = NowUtc
        };
        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();
        return user;
    }

    private static async Task<Server> AddServerAsync(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var server = new Server
        {
            CPU = "AMD EPYC",
            GPU = "NVIDIA H100",
            RAM = "128GB",
            Storage = "2TB",
            OS = "Ubuntu",
            PricePerHour = 100,
            PricePerDay = 1000,
            IsActive = true
        };
        dbContext.Servers.Add(server);
        await dbContext.SaveChangesAsync();
        return server;
    }

    private static Reservation Reservation(
        int userId,
        int serverId,
        ReservationStatus status,
        DateTime endTime,
        string? ip = null,
        string? username = null,
        string? password = null) => new()
    {
        UserId = userId,
        ServerId = serverId,
        StartTime = NowUtc.AddHours(-1),
        EndTime = endTime,
        TotalPrice = 100,
        Status = status,
        AssignedIp = ip,
        AssignedUsername = username,
        AssignedPassword = password
    };

    private static SupportConversation Conversation(
        int userId,
        SupportConversationStatus status,
        int adminUnreadCount,
        int? assignedAdminId = null) => new()
    {
        Id = Guid.NewGuid(),
        UserId = userId,
        Title = "Phase 2 support",
        Status = status,
        AssignedAdminUserId = assignedAdminId,
        CreatedAt = NowUtc,
        UpdatedAt = NowUtc,
        ReadState = new SupportConversationReadState
        {
            AdminUnreadCount = adminUnreadCount
        }
    };

    private sealed class AcceptingCaptchaService : ICaptchaService
    {
        public CaptchaChallengeResponseDto CreateChallenge() => new() { CaptchaId = "accepted", A = 1, B = 1 };
        public void ValidateAndConsume(string captchaId, int captchaAnswer) { }
    }

    private sealed class NoOpEmailSender : IEmailSender
    {
        public Task SendPasswordResetCodeAsync(string toEmail, string fullName, string code, DateTime expiresAtUtc, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendEmailVerificationCodeAsync(string toEmail, string fullName, string code, DateTime expiresAtUtc, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendCurrentEmailChangeCodeAsync(string toEmail, string fullName, string code, DateTime expiresAtUtc, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendNewEmailChangeCodeAsync(string toEmail, string fullName, string code, DateTime expiresAtUtc, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class NoOpEmailVerificationService : IEmailVerificationService
    {
        public Task<EmailVerificationIssueResult?> IssueCodeAsync(int userId, bool enforceResendCooldown, CancellationToken cancellationToken = default) => Task.FromResult<EmailVerificationIssueResult?>(null);
        public Task ValidateAndConsumeAsync(int userId, string code, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class NoOpPasswordResetCodeService : IPasswordResetCodeService
    {
        public Task<PasswordResetCodeIssueResult?> IssueCodeAsync(int userId, bool enforceCooldown, CancellationToken cancellationToken = default) => Task.FromResult<PasswordResetCodeIssueResult?>(null);
        public Task ValidateAndConsumeAsync(int userId, string code, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
