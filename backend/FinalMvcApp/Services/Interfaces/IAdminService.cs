using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.DTOs.Export;

namespace FinalMvcApp.Services.Interfaces;

public interface IAdminService
{
    Task<DashboardStatsDto> GetDashboardStatsAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AdminUserDto>> GetUsersAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AdminOrderDto>> GetOrdersAsync(CancellationToken cancellationToken = default);

    Task<AdminReservationDetailDto> AssignCredentialsAsync(
        AssignCredentialsDto dto,
        CancellationToken cancellationToken = default);

    Task<AdminReservationDetailDto> AssignCredentialsAsync(
        int adminUserId,
        AssignCredentialsDto dto,
        CancellationToken cancellationToken = default);

    Task<FileResultDto> ExportOrdersExcelAsync(CancellationToken cancellationToken = default);
}
