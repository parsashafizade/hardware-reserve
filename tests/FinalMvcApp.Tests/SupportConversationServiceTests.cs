using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Tests;

public class SupportConversationServiceTests
{
    [Fact]
    public async Task SendMessage_IsOrderedAndIdempotent_AndUpdatesUnreadCursor()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "support-order@test.local");
        var service = SupportTestFactory.CreateSupportService(dbContext);
        var conversation = await service.CreateForUserAsync(user.Id, new CreateSupportConversationRequestDto());

        var first = await service.SendForUserAsync(
            user.Id,
            conversation.Id,
            new SendSupportMessageRequestDto
            {
                ClientMessageId = "message-0001",
                Content = "First message"
            });
        var duplicate = await service.SendForUserAsync(
            user.Id,
            conversation.Id,
            new SendSupportMessageRequestDto
            {
                ClientMessageId = "message-0001",
                Content = "First message"
            });
        var conflictingRetry = () => service.SendForUserAsync(
            user.Id,
            conversation.Id,
            new SendSupportMessageRequestDto
            {
                ClientMessageId = "message-0001",
                Content = "A different payload under the same idempotency key"
            });
        var conflict = await Assert.ThrowsAsync<InvalidOperationException>(conflictingRetry);
        var second = await service.SendForUserAsync(
            user.Id,
            conversation.Id,
            new SendSupportMessageRequestDto
            {
                ClientMessageId = "message-0002",
                Content = "Second message"
            });

        Assert.False(first.IsDuplicate);
        Assert.True(duplicate.IsDuplicate);
        Assert.Equal(first.Message.Id, duplicate.Message.Id);
        Assert.Contains("different message content", conflict.Message);
        Assert.Equal(1, first.Message.SequenceNumber);
        Assert.Equal(2, second.Message.SequenceNumber);
        Assert.Equal(2, await dbContext.SupportMessages.CountAsync());

        var history = await service.GetMessagesForUserAsync(
            user.Id,
            conversation.Id,
            new SupportMessageQueryDto());
        Assert.Equal(new long[] { 1, 2 }, history.Messages.Items.Select(message => message.SequenceNumber));
        Assert.All(history.Messages.Items, message => Assert.Equal("PLAIN_TEXT", message.ContentFormat));

        var readState = await dbContext.SupportConversationReadStates.SingleAsync();
        Assert.Equal(2, readState.UserLastReadSequence);
        Assert.Equal(0, readState.UserUnreadCount);
        Assert.Equal(2, readState.AdminUnreadCount);
    }

    [Fact]
    public async Task ResolvedConversation_ReopensOnUserMessage_AndClosedConversationRejectsMessages()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "support-life@test.local");
        var admin = await SupportTestFactory.AddUserAsync(dbContext, "support-admin@test.local", UserRole.Admin);
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext);

        var conversation = await userService.CreateForUserAsync(user.Id, new CreateSupportConversationRequestDto());
        await userService.SendForUserAsync(
            user.Id,
            conversation.Id,
            Message("lifecycle-0001", "I need an administrator."));
        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);
        await adminService.ClaimAsync(admin.Id, conversation.Id);
        await adminService.ResolveAsync(admin.Id, conversation.Id);

        var reopened = await userService.SendForUserAsync(
            user.Id,
            conversation.Id,
            Message("lifecycle-0002", "I have another question."));

        Assert.Equal("AI_ACTIVE", reopened.Conversation.Status);
        Assert.Null(reopened.Conversation.ResolvedAt);

        var stored = await dbContext.SupportConversations.SingleAsync();
        Assert.Null(stored.AssignedAdminUserId);
        Assert.Contains(
            await dbContext.SupportConversationEvents.ToListAsync(),
            supportEvent => supportEvent.EventType == SupportAuditEventType.Reopened
                && supportEvent.PreviousStatus == SupportConversationStatus.RESOLVED
                && supportEvent.NewStatus == SupportConversationStatus.AI_ACTIVE);

        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);
        await adminService.ClaimAsync(admin.Id, conversation.Id);
        await adminService.CloseAsync(admin.Id, conversation.Id);

        var sendAfterClose = () => userService.SendForUserAsync(
            user.Id,
            conversation.Id,
            Message("lifecycle-0003", "This must not be accepted."));
        await Assert.ThrowsAsync<InvalidOperationException>(sendAfterClose);
        Assert.Equal(2, await dbContext.SupportMessages.CountAsync());
    }

    [Fact]
    public async Task UserAndAdminReadCursors_TrackUnreadWithoutScanningMessages()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "support-read@test.local");
        var admin = await SupportTestFactory.AddUserAsync(dbContext, "support-read-admin@test.local", UserRole.Admin);
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext);

        var conversation = await userService.CreateForUserAsync(user.Id, new CreateSupportConversationRequestDto());
        await userService.SendForUserAsync(user.Id, conversation.Id, Message("read-msg-0001", "Please help."));
        Assert.Equal(1, (await adminService.GetUnreadCountAsync(admin.Id)).UnreadMessages);

        await adminService.MarkReadAsync(admin.Id, conversation.Id);
        Assert.Equal(0, (await adminService.GetUnreadCountAsync(admin.Id)).UnreadMessages);

        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);
        await adminService.ClaimAsync(admin.Id, conversation.Id);
        var reply = await adminService.SendMessageAsync(
            admin.Id,
            conversation.Id,
            Message("read-msg-0002", "Support reply"));

        Assert.Equal("Support Team", reply.Message.SenderDisplayName);
        Assert.Equal(1, (await userService.GetUnreadCountForUserAsync(user.Id)).UnreadMessages);

        await userService.MarkReadForUserAsync(user.Id, conversation.Id);
        Assert.Equal(0, (await userService.GetUnreadCountForUserAsync(user.Id)).UnreadMessages);

        var readState = await dbContext.SupportConversationReadStates.SingleAsync();
        Assert.Equal(2, readState.UserLastReadSequence);
        Assert.Equal(2, readState.AdminLastReadSequence);
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
