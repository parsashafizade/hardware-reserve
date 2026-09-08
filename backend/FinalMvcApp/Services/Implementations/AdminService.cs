using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.DTOs.Export;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using OfficeOpenXml;
using System.Globalization;

namespace FinalMvcApp.Services.Implementations;

public class AdminService : IAdminService
{
    private readonly IUserRepository _userRepository;
    private readonly IServerRepository _serverRepository;
    private readonly IReservationRepository _reservationRepository;
    private readonly IPaymentRepository _paymentRepository;
    private readonly IServiceDetailsNotificationService _serviceDetailsNotificationService;
    private readonly IAdminControlRepository? _adminControlRepository;
    private readonly TimeProvider _timeProvider;

    public AdminService(
        IUserRepository userRepository,
        IServerRepository serverRepository,
        IReservationRepository reservationRepository,
        IPaymentRepository paymentRepository,
        IServiceDetailsNotificationService serviceDetailsNotificationService,
        IAdminControlRepository? adminControlRepository = null,
        TimeProvider? timeProvider = null)
    {
        _userRepository = userRepository;
        _serverRepository = serverRepository;
        _reservationRepository = reservationRepository;
        _paymentRepository = paymentRepository;
        _serviceDetailsNotificationService = serviceDetailsNotificationService;
        _adminControlRepository = adminControlRepository;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    public async Task<DashboardStatsDto> GetDashboardStatsAsync(CancellationToken cancellationToken = default)
    {
        var users = await _userRepository.GetAllAsync(cancellationToken);
        var servers = await _serverRepository.GetAllAsync(cancellationToken);
        var payments = await _paymentRepository.GetAllAsync(cancellationToken);

        var response = new DashboardStatsDto
        {
            TotalUsers = users.Count,
            TotalServers = servers.Count,
            TotalPurchases = payments.Count(payment => payment.Status == PaymentStatus.Completed)
        };

        if (_adminControlRepository is null)
        {
            return response;
        }

        var operational = await _adminControlRepository.GetOperationalCountsAsync(
            _timeProvider.GetUtcNow().UtcDateTime,
            cancellationToken);
        var audits = await _adminControlRepository.GetRecentAuditEventsAsync(8, cancellationToken);
        response.ActiveReservations = operational.ActiveReservations;
        response.UpcomingReservations = operational.UpcomingReservations;
        response.StartingSoonReservations = operational.StartingSoonReservations;
        response.EndingSoonReservations = operational.EndingSoonReservations;
        response.PendingPayments = operational.PendingPayments;
        response.UnavailableServers = operational.UnavailableServers;
        response.MaintenanceServers = operational.MaintenanceServers;
        response.WaitingSupportConversations = operational.WaitingSupportConversations;
        response.PendingAssignmentReservations = operational.PendingAssignmentReservations;
        response.SupportAttentionConversations = operational.SupportAttentionConversations;
        response.RecentAuditEvents = audits.Select(item => new AdminAuditEventDto
        {
            Id = item.Id,
            AdminUserId = item.AdminUserId,
            Action = item.Action.ToString(),
            EntityType = item.EntityType,
            EntityId = item.EntityId,
            Details = item.Details,
            CreatedAt = item.CreatedAt
        }).ToList();
        return response;
    }

    public async Task<IReadOnlyList<AdminUserDto>> GetUsersAsync(CancellationToken cancellationToken = default)
    {
        var users = await _userRepository.GetAllAsync(cancellationToken);

        return users
            .OrderByDescending(user => user.CreatedAt)
            .Select(user => new AdminUserDto
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                Role = user.Role.ToString(),
                CreatedAt = user.CreatedAt,
                IsEmailVerified = user.IsEmailVerified
            })
            .ToList();
    }

    public async Task<IReadOnlyList<AdminOrderDto>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        var reservations = await _reservationRepository.GetAllWithDetailsAsync(cancellationToken);

        return reservations
            .Select(MapOrder)
            .ToList();
    }

    public Task<AdminReservationDetailDto> AssignCredentialsAsync(
        AssignCredentialsDto dto,
        CancellationToken cancellationToken = default)
    {
        return AssignCredentialsCoreAsync(null, dto, cancellationToken);
    }

    public Task<AdminReservationDetailDto> AssignCredentialsAsync(
        int adminUserId,
        AssignCredentialsDto dto,
        CancellationToken cancellationToken = default)
    {
        return AssignCredentialsCoreAsync(adminUserId, dto, cancellationToken);
    }

    private async Task<AdminReservationDetailDto> AssignCredentialsCoreAsync(
        int? adminUserId,
        AssignCredentialsDto dto,
        CancellationToken cancellationToken)
    {
        var assignment = await _reservationRepository.AssignCredentialsAsync(
                dto.ReservationId,
                dto.AssignedIp.Trim(),
                dto.AssignedUsername.Trim(),
                dto.AssignedPassword.Trim(),
                cancellationToken)
            ?? throw new KeyNotFoundException("Reservation not found.");

        if (!assignment.IsEligible)
        {
            throw new InvalidOperationException("Credentials can only be assigned to paid reservations.");
        }

        var reservation = assignment.Reservation;
        await _serviceDetailsNotificationService.EnsureDeliveredAsync(
            reservation,
            assignment.ServiceDetailsVersion,
            cancellationToken);
        if (!assignment.Changed)
        {
            return MapDetail(reservation);
        }

        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        if (adminUserId.HasValue && _adminControlRepository is not null)
        {
            await _adminControlRepository.AddAuditEventAsync(new FinalMvcApp.Models.Entities.AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId.Value,
                Action = AdminAuditAction.CredentialsAssigned,
                EntityType = "Reservation",
                EntityId = reservation.Id.ToString(),
                Details = assignment.WasPreviouslyAssigned
                    ? $"Connection access updated for reservation #{reservation.Id}"
                    : $"Connection access assigned to reservation #{reservation.Id}",
                CreatedAt = nowUtc
            }, cancellationToken);
            await _adminControlRepository.SaveChangesAsync(cancellationToken);
        }

        return MapDetail(reservation);
    }

    public async Task<FileResultDto> ExportOrdersExcelAsync(CancellationToken cancellationToken = default)
    {
        var orders = await GetOrdersAsync(cancellationToken);

        ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

        using var package = new ExcelPackage();
        var worksheet = package.Workbook.Worksheets.Add("Orders");

        worksheet.Cells[1, 1].Value = "ReservationId";
        worksheet.Cells[1, 2].Value = "UserId";
        worksheet.Cells[1, 3].Value = "UserFullName";
        worksheet.Cells[1, 4].Value = "UserEmail";
        worksheet.Cells[1, 5].Value = "ServerId";
        worksheet.Cells[1, 6].Value = "CPU";
        worksheet.Cells[1, 7].Value = "GPU";
        worksheet.Cells[1, 8].Value = "RAM";
        worksheet.Cells[1, 9].Value = "Storage";
        worksheet.Cells[1, 10].Value = "OS";
        worksheet.Cells[1, 11].Value = "StartTimeUtc";
        worksheet.Cells[1, 12].Value = "EndTimeUtc";
        worksheet.Cells[1, 13].Value = "TotalPrice";
        worksheet.Cells[1, 14].Value = "ReservationStatus";
        worksheet.Cells[1, 15].Value = "PaymentStatus";

        for (var row = 0; row < orders.Count; row++)
        {
            var order = orders[row];
            var excelRow = row + 2;

            worksheet.Cells[excelRow, 1].Value = order.ReservationId;
            worksheet.Cells[excelRow, 2].Value = order.UserId;
            worksheet.Cells[excelRow, 3].Value = order.UserFullName;
            worksheet.Cells[excelRow, 4].Value = order.UserEmail;
            worksheet.Cells[excelRow, 5].Value = order.ServerId;
            worksheet.Cells[excelRow, 6].Value = order.CPU;
            worksheet.Cells[excelRow, 7].Value = order.GPU;
            worksheet.Cells[excelRow, 8].Value = order.RAM;
            worksheet.Cells[excelRow, 9].Value = order.Storage;
            worksheet.Cells[excelRow, 10].Value = order.OS;
            worksheet.Cells[excelRow, 11].Value = order.StartTime.ToString("O", CultureInfo.InvariantCulture);
            worksheet.Cells[excelRow, 12].Value = order.EndTime.ToString("O", CultureInfo.InvariantCulture);
            worksheet.Cells[excelRow, 13].Value = order.TotalPrice;
            worksheet.Cells[excelRow, 14].Value = order.ReservationStatus;
            worksheet.Cells[excelRow, 15].Value = order.PaymentStatus;
        }

        worksheet.Cells.AutoFitColumns();

        return new FileResultDto
        {
            Content = await package.GetAsByteArrayAsync(cancellationToken),
            ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            FileName = $"orders-{DateTime.UtcNow:yyyyMMddHHmmss}.xlsx"
        };
    }

    private static AdminOrderDto MapOrder(FinalMvcApp.Models.Entities.Reservation reservation)
    {
        var credentialsAssigned = HasAssignedCredentials(reservation);
        return new AdminOrderDto
        {
            ReservationId = reservation.Id,
            UserId = reservation.UserId,
            UserFullName = reservation.User.FullName,
            UserEmail = reservation.User.Email,
            ServerId = reservation.ServerId,
            CPU = reservation.Server.CPU,
            GPU = reservation.Server.GPU,
            RAM = reservation.Server.RAM,
            Storage = reservation.Server.Storage,
            OS = reservation.Server.OS,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            ReservationStatus = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            CredentialsAssigned = credentialsAssigned,
            AssignmentStatus = credentialsAssigned ? "Assigned" : "NotAssigned"
        };
    }

    private static AdminReservationDetailDto MapDetail(
        FinalMvcApp.Models.Entities.Reservation reservation)
    {
        var credentialsAssigned = HasAssignedCredentials(reservation);
        return new AdminReservationDetailDto
        {
            ReservationId = reservation.Id,
            UserId = reservation.UserId,
            UserFullName = reservation.User.FullName,
            UserEmail = reservation.User.Email,
            ServerId = reservation.ServerId,
            CPU = reservation.Server.CPU,
            GPU = reservation.Server.GPU,
            RAM = reservation.Server.RAM,
            Storage = reservation.Server.Storage,
            OS = reservation.Server.OS,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            ReservationStatus = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            CredentialsAssigned = credentialsAssigned,
            AssignmentStatus = credentialsAssigned ? "Assigned" : "NotAssigned",
            AssignedIp = reservation.AssignedIp,
            AssignedUsername = reservation.AssignedUsername,
            AssignedPassword = reservation.AssignedPassword
        };
    }

    private static bool HasAssignedCredentials(FinalMvcApp.Models.Entities.Reservation reservation) =>
        !string.IsNullOrWhiteSpace(reservation.AssignedIp)
        && !string.IsNullOrWhiteSpace(reservation.AssignedUsername)
        && !string.IsNullOrWhiteSpace(reservation.AssignedPassword);
}
