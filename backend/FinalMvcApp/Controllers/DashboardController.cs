using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("dashboard")]
public class DashboardController : ControllerBase
{
    private readonly IAdminService _adminService;

    public DashboardController(IAdminService adminService)
    {
        _adminService = adminService;
    }

    [HttpGet("stats")]
    public async Task<ActionResult<DashboardStatsDto>> GetStats(CancellationToken cancellationToken)
    {
        var response = await _adminService.GetDashboardStatsAsync(cancellationToken);
        return Ok(response);
    }
}
