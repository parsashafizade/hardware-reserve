using System.Security.Claims;
using System.Text.Json;
using FinalMvcApp.Controllers;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace FinalMvcApp.Tests;

public class Phase3DateAndNotificationTargetingTests
{
    private static readonly DateTime NowUtc = new(2026, 8, 23, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task RecipientSearch_IsPartialCaseInsensitivePagedAndSecretFree()
    {
        await using var dbContext = TestDbFactory.Create();
        _ = await AddUserAsync(dbContext, "علی رضایی", "ali.rezaei@example.test", UserRole.User);
        _ = await AddUserAsync(dbContext, "Alice Smith", "ops.alice@example.test", UserRole.User);
        _ = await AddUserAsync(dbContext, "Unrelated", "other@example.test", UserRole.User);
        var service = BuildControlService(dbContext);

        var nameResult = await service.SearchNotificationRecipientsAsync("ALI", 1, 20);
        Assert.Equal(2, nameResult.TotalCount);
        Assert.All(nameResult.Items, item => Assert.Contains("ali", $"{item.FullName} {item.Email}".ToLowerInvariant()));

        var emailResult = await service.SearchNotificationRecipientsAsync("REZAEI@EXAMPLE", 1, 20);
        var recipient = Assert.Single(emailResult.Items);
        Assert.Equal("ali.rezaei@example.test", recipient.Email);

        for (var index = 0; index < 25; index++)
        {
            _ = await AddUserAsync(dbContext, $"Paged User {index}", $"paged-{index}@example.test", UserRole.User);
        }
        var bounded = await service.SearchNotificationRecipientsAsync("paged", 1, 100);
        Assert.Equal(20, bounded.PageSize);
        Assert.Equal(20, bounded.Items.Count);
        Assert.Equal(25, bounded.TotalCount);

        var json = JsonSerializer.Serialize(bounded.Items[0]);
        Assert.DoesNotContain("password", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("token", json, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(["Email", "FullName", "Id"], typeof(AdminNotificationRecipientDto)
            .GetProperties().Select(property => property.Name).Order().ToArray());
    }

    [Fact]
    public async Task AdminNotificationEndpoints_DenyAnonymousAndUsersButAllowAdmins()
    {
        var services = new ServiceCollection()
            .AddLogging()
            .AddAuthorization()
            .BuildServiceProvider();
        var policyProvider = services.GetRequiredService<IAuthorizationPolicyProvider>();
        var authorizeData = typeof(AdminOperationsController)
            .GetCustomAttributes(inherit: true)
            .OfType<IAuthorizeData>()
            .ToArray();
        var policy = await AuthorizationPolicy.CombineAsync(policyProvider, authorizeData);
        Assert.NotNull(policy);
        var authorization = services.GetRequiredService<IAuthorizationService>();

        Assert.False((await authorization.AuthorizeAsync(new ClaimsPrincipal(new ClaimsIdentity()), null, policy!)).Succeeded);
        Assert.False((await authorization.AuthorizeAsync(Principal(UserRole.User), null, policy)).Succeeded);
        Assert.True((await authorization.AuthorizeAsync(Principal(UserRole.Admin), null, policy)).Succeeded);
    }

    [Fact]
    public async Task SingleSelectedRecipient_ReceivesOneDurableRealtimeNotification()
    {
        await using var dbContext = TestDbFactory.Create();
        var admin = await AddUserAsync(dbContext, "Admin", "admin@example.test", UserRole.Admin);
        var selected = await AddUserAsync(dbContext, "Selected", "selected@example.test", UserRole.User);
        var realtime = new RecordingUserNotificationRealtimeNotifier();
        var service = BuildControlService(dbContext, realtime);

        var campaign = await service.SendNotificationAsync(admin.Id, Request([selected.Id]));

        Assert.Equal(AdminNotificationRecipientScope.SelectedUsers.ToString(), campaign.RecipientScope);
        Assert.Equal(selected.Id, campaign.RecipientUserId);
        Assert.Equal(1, campaign.TargetCount);
        Assert.Equal(selected.Id, Assert.Single(dbContext.UserNotifications).UserId);
        Assert.Equal(selected.Id, Assert.Single(realtime.Deliveries).UserId);
    }

    [Fact]
    public async Task MultipleSelectedRecipients_AreDeduplicatedAndDoNotReachUnrelatedUsers()
    {
        await using var dbContext = TestDbFactory.Create();
        var admin = await AddUserAsync(dbContext, "Admin", "admin@example.test", UserRole.Admin);
        var userA = await AddUserAsync(dbContext, "User A", "a@example.test", UserRole.User);
        var userB = await AddUserAsync(dbContext, "User B", "b@example.test", UserRole.User);
        var userC = await AddUserAsync(dbContext, "User C", "c@example.test", UserRole.User);
        var unrelated = await AddUserAsync(dbContext, "User D", "d@example.test", UserRole.User);
        var realtime = new RecordingUserNotificationRealtimeNotifier();
        var service = BuildControlService(dbContext, realtime);

        var campaign = await service.SendNotificationAsync(
            admin.Id,
            Request([userA.Id, userB.Id, userB.Id, userC.Id]));

        Assert.Equal(3, campaign.TargetCount);
        Assert.Null(campaign.RecipientUserId);
        Assert.Equal(
            [userA.Id, userB.Id, userC.Id],
            dbContext.UserNotifications.Select(notification => notification.UserId).OrderBy(id => id).ToArray());
        Assert.DoesNotContain(dbContext.UserNotifications, notification => notification.UserId == unrelated.Id);
        Assert.Equal(3, realtime.Deliveries.Count);
    }

    [Fact]
    public async Task MalformedTargetingIsRejectedAndExplicitBroadcastStillTargetsCustomerAccounts()
    {
        await using var dbContext = TestDbFactory.Create();
        var admin = await AddUserAsync(dbContext, "Admin", "admin@example.test", UserRole.Admin);
        var user = await AddUserAsync(dbContext, "User", "user@example.test", UserRole.User);
        var service = BuildControlService(dbContext);

        await Assert.ThrowsAsync<ValidationException>(() => service.SendNotificationAsync(admin.Id, Request([])));
        await Assert.ThrowsAsync<ValidationException>(() => service.SendNotificationAsync(admin.Id, Request([user.Id, 999_999])));
        await Assert.ThrowsAsync<ValidationException>(() => service.SendNotificationAsync(admin.Id, new AdminSendNotificationDto
        {
            RecipientScope = AdminNotificationRecipientScope.AllUsers.ToString(),
            UserIds = [user.Id],
            ConfirmBroadcast = true,
            Title = "Ambiguous",
            Message = "Must not send",
            Category = "General"
        }));
        Assert.Empty(dbContext.UserNotifications);
        Assert.Empty(dbContext.AdminNotificationCampaigns);

        var broadcast = await service.SendNotificationAsync(admin.Id, new AdminSendNotificationDto
        {
            RecipientScope = AdminNotificationRecipientScope.AllUsers.ToString(),
            ConfirmBroadcast = true,
            Title = "Broadcast",
            Message = "Explicit broadcast",
            Category = "General"
        });
        Assert.Equal(1, broadcast.TargetCount);
        Assert.Equal(user.Id, Assert.Single(dbContext.UserNotifications).UserId);
    }

    private static AdminSendNotificationDto Request(IReadOnlyList<int> userIds) => new()
    {
        RecipientScope = AdminNotificationRecipientScope.SelectedUsers.ToString(),
        UserIds = userIds,
        Title = "Targeted notice",
        Message = "Only selected recipients should receive this.",
        Category = "General"
    };

    private static ClaimsPrincipal Principal(UserRole role) => new(
        new ClaimsIdentity([new Claim(ClaimTypes.Role, role.ToString())], "Phase3Test"));

    private static AdminControlService BuildControlService(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        RecordingUserNotificationRealtimeNotifier? realtime = null)
    {
        var notificationService = new UserNotificationService(
            new UserNotificationRepository(dbContext),
            realtime ?? new RecordingUserNotificationRealtimeNotifier(),
            new FixedTimeProvider(NowUtc),
            NullLogger<UserNotificationService>.Instance);
        return new AdminControlService(
            new AdminControlRepository(dbContext),
            new ServerRepository(dbContext),
            new ReservationRepository(dbContext),
            notificationService,
            new BCryptPasswordHasher(),
            new FixedTimeProvider(NowUtc));
    }

    private static async Task<User> AddUserAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        string fullName,
        string email,
        UserRole role)
    {
        var user = new User
        {
            FullName = fullName,
            Email = email,
            PasswordHash = "not-exposed",
            Role = role,
            IsEmailVerified = true,
            EmailVerifiedAt = NowUtc,
            CreatedAt = NowUtc.AddTicks(dbContext.Users.Count())
        };
        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();
        return user;
    }
}
