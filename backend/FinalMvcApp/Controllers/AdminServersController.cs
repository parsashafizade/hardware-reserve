using FinalMvcApp.DTOs.Common;
using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Extensions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("admin/servers")]
public class AdminServersController : ControllerBase
{
    private readonly IServerService _serverService;
    private readonly IAdminControlService _adminControlService;

    public AdminServersController(
        IServerService serverService,
        IAdminControlService adminControlService)
    {
        _serverService = serverService;
        _adminControlService = adminControlService;
    }

    [HttpPost]
    public async Task<ActionResult<ServerDto>> Create(CreateServerDto request, CancellationToken cancellationToken)
    {
        var response = await _serverService.CreateAsync(User.GetUserId(), request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<ServerDto>> Update(int id, UpdateServerDto request, CancellationToken cancellationToken)
    {
        var response = await _serverService.UpdateAsync(User.GetUserId(), id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    public async Task<ActionResult<MessageResponseDto>> Delete(int id, CancellationToken cancellationToken)
    {
        await _serverService.SoftDeleteAsync(User.GetUserId(), id, cancellationToken);

        return Ok(new MessageResponseDto
        {
            Message = "Server soft-deleted successfully."
        });
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ServerDto>>> GetAll(CancellationToken cancellationToken)
    {
        var response = await _serverService.GetAllForAdminAsync(cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ServerDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _serverService.GetByIdForAdminAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}/maintenance")]
    public async Task<ActionResult<IReadOnlyList<AdminMaintenanceWindowDto>>> GetMaintenance(
        int id,
        CancellationToken cancellationToken)
    {
        return Ok(await _adminControlService.GetMaintenanceWindowsAsync(id, cancellationToken));
    }

    [HttpPost("{id:int}/maintenance")]
    public async Task<ActionResult<AdminMaintenanceWindowDto>> CreateMaintenance(
        int id,
        CreateMaintenanceWindowDto request,
        CancellationToken cancellationToken)
    {
        var response = await _adminControlService.CreateMaintenanceWindowAsync(
            User.GetUserId(),
            id,
            request,
            cancellationToken);
        return Ok(response);
    }

    [HttpDelete("maintenance/{windowId:guid}")]
    public async Task<IActionResult> RemoveMaintenance(
        Guid windowId,
        CancellationToken cancellationToken)
    {
        await _adminControlService.RemoveMaintenanceWindowAsync(
            User.GetUserId(),
            windowId,
            cancellationToken);
        return NoContent();
    }
}
