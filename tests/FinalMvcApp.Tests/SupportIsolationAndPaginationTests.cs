using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace FinalMvcApp.Tests;

public class SupportIsolationAndPaginationTests
{
    [Fact]
    public async Task ConversationOwnership_RejectsCrossUserAndAnonymousSessionAccess()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "support-owner@test.local");
        var otherUser = await SupportTestFactory.AddUserAsync(dbContext, "support-other@test.local");
        var service = SupportTestFactory.CreateSupportService(dbContext);

        var userConversation = await service.CreateForUserAsync(owner.Id, new CreateSupportConversationRequestDto());
        var crossUserSend = () => service.SendForUserAsync(
            otherUser.Id,
            userConversation.Id,
            Message("isolation-0001"));
        await Assert.ThrowsAsync<KeyNotFoundException>(crossUserSend);

        var firstAnonymous = await service.CreateAnonymousSessionAsync();
        var secondAnonymous = await service.CreateAnonymousSessionAsync();
        var anonymousConversation = await service.CreateForAnonymousAsync(
            firstAnonymous.SessionToken,
            new CreateSupportConversationRequestDto());

        var crossSessionRead = () => service.GetMessagesForAnonymousAsync(
            secondAnonymous.SessionToken,
            anonymousConversation.Id,
            new SupportMessageQueryDto());
        await Assert.ThrowsAsync<KeyNotFoundException>(crossSessionRead);

        var anonymousToUserRead = () => service.GetMessagesForAnonymousAsync(
            firstAnonymous.SessionToken,
            userConversation.Id,
            new SupportMessageQueryDto());
        await Assert.ThrowsAsync<KeyNotFoundException>(anonymousToUserRead);

        var storedSession = await dbContext.AnonymousSupportSessions.FirstAsync();
        Assert.NotEqual(firstAnonymous.SessionToken, storedSession.TokenHash);
        Assert.Equal(64, storedSession.TokenHash.Length);
    }

    [Fact]
    public async Task CursorPagination_ReturnsStableConversationAndMessagePagesWithoutDuplicates()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "support-page@test.local");
        var service = SupportTestFactory.CreateSupportService(dbContext);

        for (var index = 1; index <= 3; index++)
        {
            await service.CreateForUserAsync(
                user.Id,
                new CreateSupportConversationRequestDto { Title = $"Conversation {index}" });
        }

        var firstConversationPage = await service.GetForUserAsync(
            user.Id,
            new SupportConversationQueryDto { PageSize = 2 });
        var secondConversationPage = await service.GetForUserAsync(
            user.Id,
            new SupportConversationQueryDto
            {
                PageSize = 2,
                Cursor = firstConversationPage.NextCursor
            });

        Assert.True(firstConversationPage.HasMore);
        Assert.NotNull(firstConversationPage.NextCursor);
        Assert.Single(secondConversationPage.Items);
        Assert.Empty(firstConversationPage.Items.Select(item => item.Id)
            .Intersect(secondConversationPage.Items.Select(item => item.Id)));

        var conversationId = firstConversationPage.Items[0].Id;
        for (var index = 1; index <= 5; index++)
        {
            await service.SendForUserAsync(
                user.Id,
                conversationId,
                new SendSupportMessageRequestDto
                {
                    ClientMessageId = $"page-message-{index:0000}",
                    Content = $"Message {index}"
                });
        }

        var pageOne = await service.GetMessagesForUserAsync(
            user.Id,
            conversationId,
            new SupportMessageQueryDto { PageSize = 2 });
        var pageTwo = await service.GetMessagesForUserAsync(
            user.Id,
            conversationId,
            new SupportMessageQueryDto { PageSize = 2, Cursor = pageOne.Messages.NextCursor });
        var pageThree = await service.GetMessagesForUserAsync(
            user.Id,
            conversationId,
            new SupportMessageQueryDto { PageSize = 2, Cursor = pageTwo.Messages.NextCursor });

        Assert.Equal(new long[] { 4, 5 }, pageOne.Messages.Items.Select(message => message.SequenceNumber));
        Assert.Equal(new long[] { 2, 3 }, pageTwo.Messages.Items.Select(message => message.SequenceNumber));
        Assert.Equal(new long[] { 1 }, pageThree.Messages.Items.Select(message => message.SequenceNumber));
        Assert.False(pageThree.Messages.HasMore);
    }

    [Fact]
    public async Task AdminOperations_RequireAdminRole_AndClaimControlsReplyAndCloseFlow()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "support-admin-boundary@test.local");
        var otherAdmin = await SupportTestFactory.AddUserAsync(dbContext, "support-other-admin@test.local", UserRole.Admin);
        var admin = await SupportTestFactory.AddUserAsync(dbContext, "support-main-admin@test.local", UserRole.Admin);
        var userService = SupportTestFactory.CreateSupportService(dbContext);
        var adminService = SupportTestFactory.CreateAdminService(dbContext);

        var conversation = await userService.CreateForUserAsync(user.Id, new CreateSupportConversationRequestDto());
        var nonAdminList = () => adminService.GetConversationsAsync(
            user.Id,
            new AdminSupportConversationQueryDto());
        await Assert.ThrowsAsync<UnauthorizedAccessException>(nonAdminList);

        await userService.RequestAdminForUserAsync(user.Id, conversation.Id);
        var claimed = await adminService.ClaimAsync(admin.Id, conversation.Id);
        Assert.Equal("ADMIN_ACTIVE", claimed.Status);
        Assert.True(claimed.IsAssignedToCurrentAdmin);

        var otherAdminReply = () => adminService.SendMessageAsync(
            otherAdmin.Id,
            conversation.Id,
            Message("admin-boundary-0001"));
        await Assert.ThrowsAsync<InvalidOperationException>(otherAdminReply);

        var adminMessage = Message("admin-boundary-0002");
        var firstReply = await adminService.SendMessageAsync(admin.Id, conversation.Id, adminMessage);
        var duplicateReply = await adminService.SendMessageAsync(admin.Id, conversation.Id, adminMessage);
        Assert.False(firstReply.IsDuplicate);
        Assert.True(duplicateReply.IsDuplicate);
        Assert.Equal(firstReply.Message.Id, duplicateReply.Message.Id);

        var conflictingReply = () => adminService.SendMessageAsync(
            admin.Id,
            conversation.Id,
            new SendSupportMessageRequestDto
            {
                ClientMessageId = "admin-boundary-0002",
                Content = "Different reply content"
            });
        await Assert.ThrowsAsync<InvalidOperationException>(conflictingReply);

        var resolved = await adminService.ResolveAsync(admin.Id, conversation.Id);
        Assert.Equal("RESOLVED", resolved.Status);
        Assert.NotNull(resolved.ResolvedAt);

        var closed = await adminService.CloseAsync(admin.Id, conversation.Id);
        Assert.Equal("CLOSED", closed.Status);
        Assert.NotNull(closed.ClosedAt);
    }

    private static SendSupportMessageRequestDto Message(string clientMessageId)
    {
        return new SendSupportMessageRequestDto
        {
            ClientMessageId = clientMessageId,
            Content = "Support test message"
        };
    }
}
