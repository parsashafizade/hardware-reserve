using FinalMvcApp.DTOs.Servers;

namespace FinalMvcApp.Services.Interfaces;

public interface IServerService
{
    Task<ServerDto> CreateAsync(CreateServerDto dto, CancellationToken cancellationToken = default);

    Task<ServerDto> CreateAsync(int adminUserId, CreateServerDto dto, CancellationToken cancellationToken = default);

    Task<ServerDto> UpdateAsync(int id, UpdateServerDto dto, CancellationToken cancellationToken = default);

    Task<ServerDto> UpdateAsync(int adminUserId, int id, UpdateServerDto dto, CancellationToken cancellationToken = default);

    Task SoftDeleteAsync(int id, CancellationToken cancellationToken = default);

    Task SoftDeleteAsync(int adminUserId, int id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ServerDto>> GetAllForAdminAsync(CancellationToken cancellationToken = default);

    Task<ServerDto> GetByIdForAdminAsync(int id, CancellationToken cancellationToken = default);

    Task<ServerDto> GetByIdPublicAsync(int id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ServerDto>> GetActiveFilteredAsync(ServerFilterDto filter, CancellationToken cancellationToken = default);
}
