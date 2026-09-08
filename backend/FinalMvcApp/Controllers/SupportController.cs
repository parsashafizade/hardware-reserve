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
[Authorize]
[EnableRateLimiting(SupportRateLimitPolicies.Standard)]
[RequestSizeLimit(32 * 1024)]
[Route("support")]
public class SupportController : ControllerBase
{
    private readonly ISupportService _supportService;

    public SupportController(ISupportService supportService)
    {
        _supportService = supportService;
    }

    [HttpPost("conversations")]
    public async Task<ActionResult<SupportConversationSummaryDto>> CreateConversation(
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.CreateForUserAsync(
            User.GetUserId(),
            request,
            cancellationToken);
        return StatusCode(StatusCodes.Status201Created, response);
    }

    [HttpGet("conversations")]
    public async Task<ActionResult<CursorPageDto<SupportConversationSummaryDto>>> GetConversations(
        [FromQuery] SupportConversationQueryDto query,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.GetForUserAsync(User.GetUserId(), query, cancellationToken);
        return Ok(response);
    }

    [HttpGet("conversations/{conversationId:guid}/messages")]
    public async Task<ActionResult<SupportMessageHistoryDto>> GetMessages(
        Guid conversationId,
        [FromQuery] SupportMessageQueryDto query,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.GetMessagesForUserAsync(
            User.GetUserId(),
            conversationId,
            query,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/messages")]
    [EnableRateLimiting(SupportRateLimitPolicies.Message)]
    public async Task<ActionResult<SendSupportMessageResponseDto>> SendMessage(
        Guid conversationId,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.SendForUserAsync(
            User.GetUserId(),
            conversationId,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/request-admin")]
    public async Task<ActionResult<SupportConversationSummaryDto>> RequestAdmin(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.RequestAdminForUserAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/read")]
    public async Task<ActionResult<SupportUnreadCountDto>> MarkRead(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var response = await _supportService.MarkReadForUserAsync(
            User.GetUserId(),
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<SupportUnreadCountDto>> GetUnreadCount(CancellationToken cancellationToken)
    {
        var response = await _supportService.GetUnreadCountForUserAsync(User.GetUserId(), cancellationToken);
        return Ok(response);
    }
}
