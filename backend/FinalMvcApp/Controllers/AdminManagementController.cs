using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FinalMvcApp.Extensions;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("admin")]
public class AdminManagementController : ControllerBase
{
    private readonly IAdminService _adminService;

    public AdminManagementController(IAdminService adminService)
    {
        _adminService = adminService;
    }

    [HttpGet("users")]
    public async Task<ActionResult<IReadOnlyList<AdminUserDto>>> GetUsers(CancellationToken cancellationToken)
    {
        var response = await _adminService.GetUsersAsync(cancellationToken);
        return Ok(response);
    }

    [HttpGet("orders")]
    public async Task<ActionResult<IReadOnlyList<AdminOrderDto>>> GetOrders(CancellationToken cancellationToken)
    {
        var response = await _adminService.GetOrdersAsync(cancellationToken);
        return Ok(response);
    }

    [HttpPost("assign-credentials")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<ActionResult<AdminReservationDetailDto>> AssignCredentials(
        AssignCredentialsDto request,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminService.AssignCredentialsAsync(
            User.GetUserId(),
            request,
            cancellationToken));
    }

    [HttpGet("export/excel")]
    public async Task<IActionResult> ExportExcel(CancellationToken cancellationToken)
    {
        var file = await _adminService.ExportOrdersExcelAsync(cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }
}
