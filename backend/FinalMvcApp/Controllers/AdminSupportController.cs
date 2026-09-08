using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Extensions;
using FinalMvcApp.Options;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[EnableRateLimiting(SupportRateLimitPolicies.Standard)]
[RequestSizeLimit(32 * 1024)]
[Route("admin/support")]
public class AdminSupportController : ControllerBase
{
    private readonly IAdminSupportService _adminSupportService;

    public AdminSupportController(IAdminSupportService adminSupportService)
    {
        _adminSupportService = adminSupportService;
    }

    [HttpGet("conversations")]
    public async Task<ActionResult<CursorPageDto<AdminSupportConversationDto>>> GetConversations(
        [FromQuery] AdminSupportConversationQueryDto query,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GetConversationsAsync(
            User.GetUserId(),
            query,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("conversations/{conversationId:guid}/messages")]
    public async Task<ActionResult<AdminSupportMessageHistoryDto>> GetMessages(
        Guid conversationId,
        [FromQuery] SupportMessageQueryDto query,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GetMessagesAsync(
            User.GetUserId(),
            conversationId,
            query,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("conversations/{conversationId:guid}/events")]
    public async Task<ActionResult<CursorPageDto<SupportConversationEventDto>>> GetEvents(
        Guid conversationId,
        [FromQuery] SupportMessageQueryDto query,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GetEventsAsync(
            User.GetUserId(),
            conversationId,
            query,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/claim")]
    public async Task<ActionResult<AdminSupportConversationDto>> Claim(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.ClaimAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/messages")]
    [EnableRateLimiting(SupportRateLimitPolicies.Message)]
    public async Task<ActionResult<AdminSendSupportMessageResponseDto>> SendMessage(
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.SendMessageAsync(
            User.GetUserId(),
            conversationId,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/read")]
    public async Task<ActionResult<SupportUnreadCountDto>> MarkRead(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.MarkReadAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/resolve")]
    public async Task<ActionResult<AdminSupportConversationDto>> Resolve(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.ResolveAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/close")]
    public async Task<ActionResult<AdminSupportConversationDto>> Close(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.CloseAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPut("conversations/{conversationId:guid}/title")]
    public async Task<ActionResult<AdminSupportConversationDto>> UpdateTitle(
        Guid conversationId,
        UpdateSupportConversationTitleRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.UpdateTitleAsync(
            User.GetUserId(),
            conversationId,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<SupportUnreadCountDto>> GetUnreadCount(CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GetUnreadCountAsync(User.GetUserId(), cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/suggest-reply")]
    [EnableRateLimiting(SupportRateLimitPolicies.Message)]
    public async Task<ActionResult<SupportSuggestedReplyDto>> GenerateSuggestedReply(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GenerateSuggestedReplyAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("quick-replies")]
    public async Task<ActionResult<IReadOnlyList<SupportQuickReplyDto>>> GetQuickReplies(
        [FromQuery] bool includeInactive,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.GetQuickRepliesAsync(
            User.GetUserId(),
            includeInactive,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("quick-replies")]
    public async Task<ActionResult<SupportQuickReplyDto>> CreateQuickReply(
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.CreateQuickReplyAsync(
            User.GetUserId(),
            request,
            cancellationToken);
        return StatusCode(StatusCodes.Status201Created, response);
    }

    [HttpPut("quick-replies/{quickReplyId:guid}")]
    public async Task<ActionResult<SupportQuickReplyDto>> UpdateQuickReply(
        Guid quickReplyId,
        UpsertSupportQuickReplyRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _adminSupportService.UpdateQuickReplyAsync(
            User.GetUserId(),
            quickReplyId,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpDelete("quick-replies/{quickReplyId:guid}")]
    public async Task<IActionResult> DeactivateQuickReply(
        Guid quickReplyId,
        CancellationToken cancellationToken)
    {
        await _adminSupportService.DeactivateQuickReplyAsync(
            User.GetUserId(),
            quickReplyId,
            cancellationToken);
        return NoContent();
    }
}
