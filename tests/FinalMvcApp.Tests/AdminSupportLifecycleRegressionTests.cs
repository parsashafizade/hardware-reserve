using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Tests;

public class AdminSupportLifecycleRegressionTests
{
    [Fact]
    public async Task ClaimThenClose_PersistsOnce_SettlesAdminUnread_AndServiceRemainsUsable()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "close-regression-user@test.local");
        var admin = await SupportTestFactory.AddUserAsync(
            dbContext,
            "close-regression-admin@test.local",
            UserRole.Admin);
        var notifier = new RecordingSupportNotifier();
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext, notifier);

        var conversation = await userService.CreateForUserAsync(
            user.Id,
            new CreateSupportConversationRequestDto { Title = "Claim and close regression" });
        await userService.SendForUserAsync(
            user.Id,
            conversation.Id,
            Message("close-regression-message", "Please close this conversation."));
        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);

        await adminService.ClaimAsync(admin.Id, conversation.Id);
        var closed = await adminService.CloseAsync(admin.Id, conversation.Id);
        var duplicateClose = await adminService.CloseAsync(admin.Id, conversation.Id);

        Assert.Equal("CLOSED", closed.Status);
        Assert.Equal(closed.ClosedAt, duplicateClose.ClosedAt);
        Assert.NotNull(closed.ClosedAt);

        var stored = await dbContext.SupportConversations.SingleAsync();
        Assert.Equal(SupportConversationStatus.CLOSED, stored.Status);
        Assert.Equal(admin.Id, stored.AssignedAdminUserId);

        var readState = await dbContext.SupportConversationReadStates.SingleAsync();
        Assert.Equal(stored.LastMessageSequence, readState.AdminLastReadSequence);
        Assert.Equal(0, readState.AdminUnreadCount);
        Assert.NotNull(readState.AdminReadAt);
        Assert.Equal(0, (await adminService.GetUnreadCountAsync(admin.Id)).UnreadMessages);

        Assert.Single(
            await dbContext.SupportConversationEvents
                .Where(supportEvent => supportEvent.EventType == SupportAuditEventType.Closed)
                .ToListAsync());
        Assert.Single(
            notifier.Notifications,
            notification => notification.ConversationId == conversation.Id
                && notification.EventType == "CONVERSATION_CLOSED");

        var persistedPage = await adminService.GetConversationsAsync(
            admin.Id,
            new AdminSupportConversationQueryDto { Status = "CLOSED" });
        Assert.Contains(persistedPage.Items, item => item.Id == conversation.Id);
    }

    [Fact]
    public async Task LifecycleTransitions_RequireClaimOwner_AndAllowOwnedResolvedToClose()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "lifecycle-owner-user@test.local");
        var assignedAdmin = await SupportTestFactory.AddUserAsync(
            dbContext,
            "lifecycle-owner-admin@test.local",
            UserRole.Admin);
        var staleAdmin = await SupportTestFactory.AddUserAsync(
            dbContext,
            "lifecycle-stale-admin@test.local",
            UserRole.Admin);
        var notifier = new RecordingSupportNotifier();
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext, notifier);

        var conversation = await userService.CreateForUserAsync(
            user.Id,
            new CreateSupportConversationRequestDto());
        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => adminService.CloseAsync(assignedAdmin.Id, conversation.Id));
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => adminService.ResolveAsync(assignedAdmin.Id, conversation.Id));

        await adminService.ClaimAsync(assignedAdmin.Id, conversation.Id);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => adminService.ClaimAsync(staleAdmin.Id, conversation.Id));
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => adminService.ResolveAsync(staleAdmin.Id, conversation.Id));
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => adminService.CloseAsync(staleAdmin.Id, conversation.Id));

        var reply = await adminService.SendMessageAsync(
            assignedAdmin.Id,
            conversation.Id,
            Message("lifecycle-owner-reply", "This conversation is ready to resolve."));
        var resolved = await adminService.ResolveAsync(assignedAdmin.Id, conversation.Id);
        var duplicateResolve = await adminService.ResolveAsync(assignedAdmin.Id, conversation.Id);
        var closed = await adminService.CloseAsync(assignedAdmin.Id, conversation.Id);

        Assert.False(reply.IsDuplicate);
        Assert.Equal("RESOLVED", resolved.Status);
        Assert.Equal(resolved.ResolvedAt, duplicateResolve.ResolvedAt);
        Assert.Equal("CLOSED", closed.Status);
        Assert.Equal(resolved.ResolvedAt, closed.ResolvedAt);

        var readState = await dbContext.SupportConversationReadStates.SingleAsync();
        Assert.Equal(0, readState.AdminUnreadCount);
        Assert.Equal(1, readState.UserUnreadCount);
        Assert.Equal(1, (await userService.GetUnreadCountForUserAsync(user.Id)).UnreadMessages);

        var lifecycleEvents = await dbContext.SupportConversationEvents
            .Where(supportEvent => supportEvent.ConversationId == conversation.Id)
            .ToListAsync();
        Assert.Single(lifecycleEvents, supportEvent => supportEvent.EventType == SupportAuditEventType.AdminClaimed);
        Assert.Single(lifecycleEvents, supportEvent => supportEvent.EventType == SupportAuditEventType.Resolved);
        Assert.Single(lifecycleEvents, supportEvent => supportEvent.EventType == SupportAuditEventType.Closed);
        Assert.Single(notifier.Notifications, notification => notification.EventType == "CONVERSATION_RESOLVED");
        Assert.Single(notifier.Notifications, notification => notification.EventType == "CONVERSATION_CLOSED");
    }

    [Fact]
    public async Task LifecycleTransitions_RejectNormalUserServiceCalls()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "lifecycle-auth-user@test.local");
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext);
        var conversation = await userService.CreateForUserAsync(
            user.Id,
            new CreateSupportConversationRequestDto());

        await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => adminService.ResolveAsync(user.Id, conversation.Id));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => adminService.CloseAsync(user.Id, conversation.Id));
    }

    private static SendSupportMessageRequestDto Message(string clientMessageId, string content)
    {
        return new SendSupportMessageRequestDto
        {
            ClientMessageId = clientMessageId,
            Content = content
        };
    }
}
