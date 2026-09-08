using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Controllers;

[ApiController]
[Route("servers")]
public class ServersController : ControllerBase
{
    private readonly IServerService _serverService;

    public ServersController(IServerService serverService)
    {
        _serverService = serverService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ServerDto>>> Get([FromQuery] ServerFilterDto filter, CancellationToken cancellationToken)
    {
        var response = await _serverService.GetActiveFilteredAsync(filter, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ServerDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _serverService.GetByIdPublicAsync(id, cancellationToken);
        return Ok(response);
    }
}
