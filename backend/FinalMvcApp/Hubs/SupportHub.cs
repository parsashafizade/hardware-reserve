using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace FinalMvcApp.Hubs;

[Authorize]
public class SupportHub : Hub
{
    private readonly ISupportService _supportService;

    public SupportHub(ISupportService supportService)
    {
        _supportService = supportService;
    }

    public override async Task OnConnectedAsync()
    {
        var principal = Context.User
            ?? throw new HubException("An authenticated user is required.");
        var userId = principal.GetUserId();
        await Groups.AddToGroupAsync(Context.ConnectionId, SupportHubGroups.User(userId));

        if (principal.IsInRole("Admin"))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, SupportHubGroups.Admins);
        }

        await base.OnConnectedAsync();
    }

    public async Task SubscribeToConversation(Guid conversationId)
    {
        var principal = Context.User
            ?? throw new HubException("An authenticated user is required.");
        var userId = principal.GetUserId();
        var canSubscribe = await _supportService.CanSubscribeAsync(
            userId,
            principal.IsInRole("Admin"),
            conversationId,
            Context.ConnectionAborted);

        if (!canSubscribe)
        {
            throw new HubException("Support conversation not found or access is denied.");
        }

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            SupportHubGroups.Conversation(conversationId),
            Context.ConnectionAborted);
    }

    public Task UnsubscribeFromConversation(Guid conversationId)
    {
        return Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            SupportHubGroups.Conversation(conversationId),
            Context.ConnectionAborted);
    }
}
