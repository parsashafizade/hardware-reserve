using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Notifications;
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
[Route("notifications")]
public class NotificationsController : ControllerBase
{
    private readonly IUserNotificationService _notificationService;

    public NotificationsController(IUserNotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    [HttpGet]
    public async Task<ActionResult<CursorPageDto<UserNotificationDto>>> Get(
        [FromQuery] NotificationQueryDto query,
        CancellationToken cancellationToken)
    {
        return Ok(await _notificationService.GetForUserAsync(
            User.GetUserId(),
            query,
            cancellationToken));
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<NotificationUnreadCountDto>> GetUnreadCount(
        CancellationToken cancellationToken)
    {
        return Ok(await _notificationService.GetUnreadCountAsync(
            User.GetUserId(),
            cancellationToken));
    }

    [HttpPost("{notificationId:guid}/read")]
    public async Task<ActionResult<UserNotificationDto>> MarkRead(
        Guid notificationId,
        CancellationToken cancellationToken)
    {
        return Ok(await _notificationService.MarkReadAsync(
            User.GetUserId(),
            notificationId,
            cancellationToken));
    }

    [HttpPost("read-all")]
    public async Task<ActionResult<NotificationUnreadCountDto>> MarkAllRead(
        CancellationToken cancellationToken)
    {
        return Ok(await _notificationService.MarkAllReadAsync(
            User.GetUserId(),
            cancellationToken));
    }
}
