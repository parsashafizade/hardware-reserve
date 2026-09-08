using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Extensions;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("admin")]
public class AdminOperationsController : ControllerBase
{
    private readonly IAdminControlService _adminControlService;

    public AdminOperationsController(IAdminControlService adminControlService)
    {
        _adminControlService = adminControlService;
    }

    [HttpGet("reservations")]
    public async Task<ActionResult<AdminPageDto<AdminOrderDto>>> GetReservations(
        [FromQuery] AdminReservationQueryDto query,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.GetReservationsAsync(query, cancellationToken));
    }

    [HttpGet("reservations/{reservationId:int}")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<ActionResult<AdminReservationDetailDto>> GetReservation(
        int reservationId,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.GetReservationAsync(reservationId, cancellationToken));
    }

    [HttpPost("reservations/{reservationId:int}/cancel")]
    public async Task<ActionResult<AdminOrderDto>> CancelReservation(
        int reservationId,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.CancelReservationAsync(
            User.GetUserId(),
            reservationId,
            cancellationToken));
    }

    [HttpGet("users/{userId:int}/overview")]
    public async Task<ActionResult<AdminUserOverviewDto>> GetUserOverview(
        int userId,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.GetUserOverviewAsync(userId, cancellationToken));
    }

    [HttpGet("users/search")]
    public async Task<ActionResult<AdminPageDto<AdminUserDto>>> SearchUsers(
        [FromQuery] string? query = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _adminControlService.SearchUsersAsync(query, page, pageSize, cancellationToken));
    }

    [HttpPost("users/admins")]
    public async Task<ActionResult<AdminUserDto>> CreateAdmin(
        CreateAdminAccountDto request,
        CancellationToken cancellationToken)
    {
        var created = await _adminControlService.CreateAdminAsync(
            User.GetUserId(),
            request,
            cancellationToken);
        return Created($"/admin/users/{created.Id}/overview", created);
    }

    [HttpGet("notification-recipients")]
    public async Task<ActionResult<AdminPageDto<AdminNotificationRecipientDto>>> SearchNotificationRecipients(
        [FromQuery] string? query = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _adminControlService.SearchNotificationRecipientsAsync(
            query,
            page,
            pageSize,
            cancellationToken));
    }

    [HttpPost("notifications")]
    public async Task<ActionResult<AdminNotificationCampaignDto>> SendNotification(
        AdminSendNotificationDto request,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.SendNotificationAsync(
            User.GetUserId(),
            request,
            cancellationToken));
    }

    [HttpGet("notifications")]
    public async Task<ActionResult<AdminPageDto<AdminNotificationCampaignDto>>> GetNotificationHistory(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _adminControlService.GetNotificationHistoryAsync(page, pageSize, cancellationToken));
    }

    [HttpGet("notification-deliveries")]
    public async Task<ActionResult<AdminPageDto<AdminNotificationHistoryItemDto>>> GetNotificationDeliveries(
        [FromQuery] AdminNotificationHistoryQueryDto query,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.GetNotificationDeliveriesAsync(query, cancellationToken));
    }

    [HttpGet("audit")]
    public async Task<ActionResult<IReadOnlyList<AdminAuditEventDto>>> GetAudit(
        [FromQuery] int take = 20,
        CancellationToken cancellationToken = default)
    {
        return Ok(await _adminControlService.GetRecentAuditEventsAsync(take, cancellationToken));
    }
}
