using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Options;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FinalMvcApp.Controllers;

[ApiController]
[AllowAnonymous]
[EnableRateLimiting(SupportRateLimitPolicies.Standard)]
[RequestSizeLimit(32 * 1024)]
[Route("support/anonymous")]
public class AnonymousSupportController : ControllerBase
{
    public const string SessionHeaderName = "X-Support-Session";
    private readonly ISupportService _supportService;

    public AnonymousSupportController(ISupportService supportService)
    {
        _supportService = supportService;
    }

    [HttpPost("sessions")]
    public async Task<ActionResult<AnonymousSupportSessionDto>> CreateSession(CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.CreateAnonymousSessionAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, response);
    }

    [HttpPost("conversations")]
    public async Task<ActionResult<SupportConversationSummaryDto>> CreateConversation(
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        CreateSupportConversationRequestDto request,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.CreateForAnonymousAsync(sessionToken, request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, response);
    }

    [HttpGet("conversations")]
    public async Task<ActionResult<CursorPageDto<SupportConversationSummaryDto>>> GetConversations(
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        [FromQuery] SupportConversationQueryDto query,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.GetForAnonymousAsync(sessionToken, query, cancellationToken);
        return Ok(response);
    }

    [HttpGet("conversations/{conversationId:guid}/messages")]
    public async Task<ActionResult<SupportMessageHistoryDto>> GetMessages(
        Guid conversationId,
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        [FromQuery] SupportMessageQueryDto query,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.GetMessagesForAnonymousAsync(
            sessionToken,
            conversationId,
            query,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/messages")]
    [EnableRateLimiting(SupportRateLimitPolicies.Message)]
    public async Task<ActionResult<SendSupportMessageResponseDto>> SendMessage(
        Guid conversationId,
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        SendSupportMessageRequestDto request,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.SendForAnonymousAsync(
            sessionToken,
            conversationId,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/request-admin")]
    public async Task<ActionResult<SupportConversationSummaryDto>> RequestAdmin(
        Guid conversationId,
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.RequestAdminForAnonymousAsync(
            sessionToken,
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpPost("conversations/{conversationId:guid}/read")]
    public async Task<ActionResult<SupportUnreadCountDto>> MarkRead(
        Guid conversationId,
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.MarkReadForAnonymousAsync(
            sessionToken,
            conversationId,
            cancellationToken);
        return Ok(response);
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<SupportUnreadCountDto>> GetUnreadCount(
        [FromHeader(Name = SessionHeaderName)] string sessionToken,
        CancellationToken cancellationToken)
    {
        EnsureAnonymousCaller();
        var response = await _supportService.GetUnreadCountForAnonymousAsync(sessionToken, cancellationToken);
        return Ok(response);
    }

    private void EnsureAnonymousCaller()
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            throw new InvalidOperationException("Use authenticated support endpoints after signing in.");
        }
    }
}
