using FinalMvcApp.DTOs.Admin;

namespace FinalMvcApp.Services.Interfaces;

public interface IAdminControlService
{
    Task<IReadOnlyList<AdminMaintenanceWindowDto>> GetMaintenanceWindowsAsync(int serverId, CancellationToken cancellationToken = default);

    Task<AdminMaintenanceWindowDto> CreateMaintenanceWindowAsync(int adminUserId, int serverId, CreateMaintenanceWindowDto request, CancellationToken cancellationToken = default);

    Task RemoveMaintenanceWindowAsync(int adminUserId, Guid windowId, CancellationToken cancellationToken = default);

    Task<AdminNotificationCampaignDto> SendNotificationAsync(int adminUserId, AdminSendNotificationDto request, CancellationToken cancellationToken = default);

    Task<AdminPageDto<AdminNotificationCampaignDto>> GetNotificationHistoryAsync(int page, int pageSize, CancellationToken cancellationToken = default);

    Task<AdminPageDto<AdminNotificationHistoryItemDto>> GetNotificationDeliveriesAsync(AdminNotificationHistoryQueryDto query, CancellationToken cancellationToken = default);

    Task<AdminPageDto<AdminOrderDto>> GetReservationsAsync(AdminReservationQueryDto query, CancellationToken cancellationToken = default);

    Task<AdminReservationDetailDto> GetReservationAsync(int reservationId, CancellationToken cancellationToken = default);

    Task<AdminOrderDto> CancelReservationAsync(int adminUserId, int reservationId, CancellationToken cancellationToken = default);

    Task<AdminUserOverviewDto> GetUserOverviewAsync(int userId, CancellationToken cancellationToken = default);

    Task<AdminPageDto<AdminUserDto>> SearchUsersAsync(string? query, int page, int pageSize, CancellationToken cancellationToken = default);

    Task<AdminPageDto<AdminNotificationRecipientDto>> SearchNotificationRecipientsAsync(string? query, int page, int pageSize, CancellationToken cancellationToken = default);

    Task<AdminUserDto> CreateAdminAsync(int actingAdminUserId, CreateAdminAccountDto request, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AdminAuditEventDto>> GetRecentAuditEventsAsync(int take, CancellationToken cancellationToken = default);
}
