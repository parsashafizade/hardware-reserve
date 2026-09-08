using AutoMapper;
using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class ServerService : IServerService
{
    private readonly IServerRepository _serverRepository;
    private readonly IMapper _mapper;
    private readonly IAdminControlRepository? _adminControlRepository;
    private readonly TimeProvider _timeProvider;

    public ServerService(
        IServerRepository serverRepository,
        IMapper mapper,
        IAdminControlRepository? adminControlRepository = null,
        TimeProvider? timeProvider = null)
    {
        _serverRepository = serverRepository;
        _mapper = mapper;
        _adminControlRepository = adminControlRepository;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public async Task<ServerDto> CreateAsync(CreateServerDto dto, CancellationToken cancellationToken = default)
    {
        return await CreateCoreAsync(null, dto, cancellationToken);
    }

    public Task<ServerDto> CreateAsync(
        int adminUserId,
        CreateServerDto dto,
        CancellationToken cancellationToken = default)
    {
        return CreateCoreAsync(adminUserId, dto, cancellationToken);
    }

    private async Task<ServerDto> CreateCoreAsync(
        int? adminUserId,
        CreateServerDto dto,
        CancellationToken cancellationToken)
    {
        var server = _mapper.Map<Server>(dto);
        server.CPU = dto.CPU.Trim();
        server.GPU = dto.GPU.Trim();
        server.RAM = dto.RAM.Trim();
        server.Storage = dto.Storage.Trim();
        server.OS = dto.OS.Trim();
        ApplyManagedConfiguration(server, dto);

        await _serverRepository.AddAsync(server, cancellationToken);
        await _serverRepository.SaveChangesAsync(cancellationToken);

        await AuditServerAsync(
            adminUserId,
            AdminAuditAction.ServerCreated,
            server,
            cancellationToken);

        return _mapper.Map<ServerDto>(server);
    }

    public async Task<ServerDto> UpdateAsync(int id, UpdateServerDto dto, CancellationToken cancellationToken = default)
    {
        return await UpdateCoreAsync(null, id, dto, cancellationToken);
    }

    public Task<ServerDto> UpdateAsync(
        int adminUserId,
        int id,
        UpdateServerDto dto,
        CancellationToken cancellationToken = default)
    {
        return UpdateCoreAsync(adminUserId, id, dto, cancellationToken);
    }

    private async Task<ServerDto> UpdateCoreAsync(
        int? adminUserId,
        int id,
        UpdateServerDto dto,
        CancellationToken cancellationToken)
    {
        var server = await _serverRepository.GetByIdAsync(id, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found.");

        server.CPU = dto.CPU.Trim();
        server.GPU = dto.GPU.Trim();
        server.RAM = dto.RAM.Trim();
        server.Storage = dto.Storage.Trim();
        server.OS = dto.OS.Trim();
        server.PricePerHour = dto.PricePerHour;
        server.PricePerDay = dto.PricePerDay;
        ApplyManagedConfiguration(server, dto);

        _serverRepository.Update(server);
        await _serverRepository.SaveChangesAsync(cancellationToken);

        await AuditServerAsync(
            adminUserId,
            AdminAuditAction.ServerConfigurationChanged,
            server,
            cancellationToken);

        return _mapper.Map<ServerDto>(server);
    }

    public async Task SoftDeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        await SoftDeleteCoreAsync(null, id, cancellationToken);
    }

    public Task SoftDeleteAsync(
        int adminUserId,
        int id,
        CancellationToken cancellationToken = default)
    {
        return SoftDeleteCoreAsync(adminUserId, id, cancellationToken);
    }

    private async Task SoftDeleteCoreAsync(
        int? adminUserId,
        int id,
        CancellationToken cancellationToken)
    {
        var server = await _serverRepository.GetByIdAsync(id, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found.");

        server.IsActive = false;
        server.OperationalStatus = ServerOperationalStatus.Disabled;

        _serverRepository.Update(server);
        await _serverRepository.SaveChangesAsync(cancellationToken);

        await AuditServerAsync(
            adminUserId,
            AdminAuditAction.ServerDisabled,
            server,
            cancellationToken);
    }

    public async Task<IReadOnlyList<ServerDto>> GetAllForAdminAsync(CancellationToken cancellationToken = default)
    {
        var servers = await _serverRepository.GetAllAsync(cancellationToken);
        return _mapper.Map<IReadOnlyList<ServerDto>>(servers);
    }

    public async Task<ServerDto> GetByIdForAdminAsync(int id, CancellationToken cancellationToken = default)
    {
        var server = await _serverRepository.GetByIdAsync(id, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found.");

        return _mapper.Map<ServerDto>(server);
    }

    public async Task<ServerDto> GetByIdPublicAsync(int id, CancellationToken cancellationToken = default)
    {
        var server = await _serverRepository.GetActiveByIdAsync(id, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found.");

        return _mapper.Map<ServerDto>(server);
    }

    public async Task<IReadOnlyList<ServerDto>> GetActiveFilteredAsync(ServerFilterDto filter, CancellationToken cancellationToken = default)
    {
        var servers = await _serverRepository.FilterActiveAsync(
            filter.CPU,
            filter.GPU,
            filter.RAM,
            filter.Storage,
            filter.OS,
            cancellationToken);

        return _mapper.Map<IReadOnlyList<ServerDto>>(servers);
    }

    private static void ApplyManagedConfiguration(Server server, CreateServerDto dto)
    {
        var operationalStatus = ParseEnum<ServerOperationalStatus>(dto.OperationalStatus, nameof(dto.OperationalStatus));
        var performanceTier = ParseEnum<ServerPerformanceTier>(dto.PerformanceTier, nameof(dto.PerformanceTier));

        if (!dto.IsActive)
        {
            operationalStatus = ServerOperationalStatus.Disabled;
        }

        server.OperationalStatus = operationalStatus;
        server.IsActive = operationalStatus != ServerOperationalStatus.Disabled;
        server.FinderEligible = dto.FinderEligible;
        server.CpuCapabilityLevel = dto.CpuCapabilityLevel;
        server.GpuCapabilityLevel = dto.GpuCapabilityLevel;
        server.PerformanceTier = performanceTier;
        ReplaceCapabilities(server, dto.WorkloadCapabilities);
    }

    private static void ApplyManagedConfiguration(Server server, UpdateServerDto dto)
    {
        var operationalStatus = ParseEnum<ServerOperationalStatus>(dto.OperationalStatus, nameof(dto.OperationalStatus));
        var performanceTier = ParseEnum<ServerPerformanceTier>(dto.PerformanceTier, nameof(dto.PerformanceTier));

        if (!dto.IsActive)
        {
            operationalStatus = ServerOperationalStatus.Disabled;
        }

        server.OperationalStatus = operationalStatus;
        server.IsActive = operationalStatus != ServerOperationalStatus.Disabled;
        server.FinderEligible = dto.FinderEligible;
        server.CpuCapabilityLevel = dto.CpuCapabilityLevel;
        server.GpuCapabilityLevel = dto.GpuCapabilityLevel;
        server.PerformanceTier = performanceTier;
        ReplaceCapabilities(server, dto.WorkloadCapabilities);
    }

    private static void ReplaceCapabilities(
        Server server,
        IReadOnlyList<ServerWorkloadCapabilityDto> capabilities)
    {
        var desired = capabilities.ToDictionary(
            capability => ParseEnum<ServerWorkloadType>(capability.WorkloadType, nameof(capability.WorkloadType)),
            capability => checked((byte)capability.SuitabilityLevel));

        foreach (var existing in server.WorkloadCapabilities.ToList())
        {
            if (!desired.TryGetValue(existing.WorkloadType, out var level))
            {
                server.WorkloadCapabilities.Remove(existing);
                continue;
            }

            existing.SuitabilityLevel = level;
            desired.Remove(existing.WorkloadType);
        }

        foreach (var capability in desired)
        {
            server.WorkloadCapabilities.Add(new ServerWorkloadCapability
            {
                ServerId = server.Id,
                WorkloadType = capability.Key,
                SuitabilityLevel = capability.Value
            });
        }
    }

    private static TEnum ParseEnum<TEnum>(string value, string fieldName)
        where TEnum : struct, Enum
    {
        if (!Enum.TryParse<TEnum>(value, true, out var parsed)
            || !Enum.IsDefined(parsed))
        {
            throw new ArgumentException($"{fieldName} is invalid.", fieldName);
        }

        return parsed;
    }

    private async Task AuditServerAsync(
        int? adminUserId,
        AdminAuditAction action,
        Server server,
        CancellationToken cancellationToken)
    {
        if (!adminUserId.HasValue || _adminControlRepository is null)
        {
            return;
        }

        await _adminControlRepository.AddAuditEventAsync(new AdminAuditEvent
        {
            Id = Guid.NewGuid(),
            AdminUserId = adminUserId.Value,
            Action = action,
            EntityType = "Server",
            EntityId = server.Id.ToString(),
            Details = $"Status {server.OperationalStatus}; Finder {server.FinderEligible}; capabilities {server.WorkloadCapabilities.Count}",
            CreatedAt = _timeProvider.GetUtcNow().UtcDateTime
        }, cancellationToken);
        await _adminControlRepository.SaveChangesAsync(cancellationToken);
    }
}
