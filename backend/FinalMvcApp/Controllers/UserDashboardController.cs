using FinalMvcApp.DTOs.Dashboard;
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
[Route("dashboard")]
public class UserDashboardController : ControllerBase
{
    private readonly IDashboardService _dashboardService;

    public UserDashboardController(IDashboardService dashboardService)
    {
        _dashboardService = dashboardService;
    }

    [HttpGet]
    public async Task<ActionResult<DashboardSummaryDto>> Get(
        CancellationToken cancellationToken)
    {
        return Ok(await _dashboardService.GetSummaryAsync(
            User.GetUserId(),
            cancellationToken));
    }

    [HttpGet("command-search")]
    public async Task<ActionResult<CommandSearchResultDto>> SearchCommands(
        [FromQuery] CommandSearchQueryDto request,
        CancellationToken cancellationToken)
    {
        return Ok(await _dashboardService.SearchCommandsAsync(
            User.GetUserId(),
            request,
            cancellationToken));
    }
}
