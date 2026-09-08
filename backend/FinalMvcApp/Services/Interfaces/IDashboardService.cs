using FinalMvcApp.DTOs.Dashboard;

namespace FinalMvcApp.Services.Interfaces;

public interface IDashboardService
{
    Task<DashboardSummaryDto> GetSummaryAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<CommandSearchResultDto> SearchCommandsAsync(
        int userId,
        CommandSearchQueryDto query,
        CancellationToken cancellationToken = default);
}
