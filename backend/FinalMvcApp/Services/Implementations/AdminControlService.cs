using FinalMvcApp.DTOs.Admin;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services;
using FinalMvcApp.Services.Interfaces;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;

namespace FinalMvcApp.Services.Implementations;

public class AdminControlService : IAdminControlService
{
    private static readonly HashSet<string> AllowedNotificationCategories = new(StringComparer.OrdinalIgnoreCase)
    {
        "General",
        "Reservation",
        "Payment",
        "Support",
        "Account"
    };

    private readonly IAdminControlRepository _adminRepository;
    private readonly IServerRepository _serverRepository;
    private readonly IReservationRepository _reservationRepository;
    private readonly IUserNotificationService _notificationService;
    private readonly IPasswordHasher _passwordHasher;
    private readonly TimeProvider _timeProvider;

    public AdminControlService(
        IAdminControlRepository adminRepository,
        IServerRepository serverRepository,
        IReservationRepository reservationRepository,
        IUserNotificationService notificationService,
        IPasswordHasher passwordHasher,
        TimeProvider timeProvider)
    {
        _adminRepository = adminRepository;
        _serverRepository = serverRepository;
        _reservationRepository = reservationRepository;
        _notificationService = notificationService;
        _passwordHasher = passwordHasher;
        _timeProvider = timeProvider;
    }

    public async Task<IReadOnlyList<AdminMaintenanceWindowDto>> GetMaintenanceWindowsAsync(
        int serverId,
        CancellationToken cancellationToken = default)
    {
        _ = await _serverRepository.GetByIdAsync(serverId, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found.");

        var windows = await _adminRepository.GetMaintenanceWindowsAsync(serverId, cancellationToken);
        return windows.Select(MapMaintenanceWindow).ToList();
    }

    public async Task<AdminMaintenanceWindowDto> CreateMaintenanceWindowAsync(
        int adminUserId,
        int serverId,
        CreateMaintenanceWindowDto request,
        CancellationToken cancellationToken = default)
    {
        var startTime = NormalizeUtc(request.StartTime);
        var endTime = NormalizeUtc(request.EndTime);
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;

        if (startTime < nowUtc || endTime <= startTime)
        {
            throw ValidationError(
                nameof(request.StartTime),
                "Maintenance must use a future valid time range.");
        }

        var window = new ServerMaintenanceWindow
        {
            Id = Guid.NewGuid(),
            ServerId = serverId,
            StartTime = startTime,
            EndTime = endTime,
            Reason = NormalizeOptional(request.Reason, 300),
            CreatedByAdminUserId = adminUserId,
            CreatedAt = nowUtc
        };

        var created = await _adminRepository.TryAddMaintenanceWindowAsync(window, cancellationToken);
        if (created is null)
        {
            throw new ApiException(
                ApiErrorCodes.ReservationTimeConflict,
                "Maintenance overlaps a reservation, another maintenance window, or an unavailable server.",
                StatusCodes.Status409Conflict);
        }

        await AddAuditAsync(
            adminUserId,
            AdminAuditAction.MaintenanceCreated,
            "ServerMaintenanceWindow",
            created.Id.ToString("N"),
            $"Server #{serverId}; {startTime:O} to {endTime:O}",
            cancellationToken);

        return MapMaintenanceWindow(created);
    }

    public async Task RemoveMaintenanceWindowAsync(
        int adminUserId,
        Guid windowId,
        CancellationToken cancellationToken = default)
    {
        var window = await _adminRepository.GetMaintenanceWindowAsync(windowId, cancellationToken)
            ?? throw new KeyNotFoundException("Maintenance window not found.");

        _adminRepository.RemoveMaintenanceWindow(window);
        await AddAuditAsync(
            adminUserId,
            AdminAuditAction.MaintenanceRemoved,
            "ServerMaintenanceWindow",
            window.Id.ToString("N"),
            $"Server #{window.ServerId}; {window.StartTime:O} to {window.EndTime:O}",
            cancellationToken);
    }

    public async Task<AdminNotificationCampaignDto> SendNotificationAsync(
        int adminUserId,
        AdminSendNotificationDto request,
        CancellationToken cancellationToken = default)
    {
        if (!Enum.TryParse<AdminNotificationRecipientScope>(request.RecipientScope, true, out var scope)
            || !Enum.IsDefined(scope))
        {
            throw ValidationError(nameof(request.RecipientScope), "RecipientScope is invalid.");
        }

        var requestedRecipientIds = ValidateRecipientSelection(scope, request);

        var category = AllowedNotificationCategories.FirstOrDefault(item =>
            string.Equals(item, request.Category.Trim(), StringComparison.OrdinalIgnoreCase));
        if (category is null)
        {
            throw ValidationError(nameof(request.Category), "Notification category is invalid.");
        }

        var recipientIds = await _adminRepository.GetNotificationRecipientIdsAsync(
            scope == AdminNotificationRecipientScope.AllUsers ? null : requestedRecipientIds,
            cancellationToken);
        if (recipientIds.Count == 0)
        {
            throw new KeyNotFoundException("Notification recipient not found.");
        }
        if (requestedRecipientIds is not null && recipientIds.Count != requestedRecipientIds.Count)
        {
            throw ValidationError(nameof(request.UserIds), "One or more selected users do not exist.");
        }

        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var campaign = new AdminNotificationCampaign
        {
            Id = Guid.NewGuid(),
            CreatedByAdminUserId = adminUserId,
            RecipientScope = scope,
            RecipientUserId = scope != AdminNotificationRecipientScope.AllUsers && recipientIds.Count == 1
                ? recipientIds[0]
                : null,
            Title = request.Title.Trim(),
            Message = request.Message.Trim(),
            Category = category,
            CreatedAt = nowUtc
        };

        await _adminRepository.AddCampaignAsync(campaign, cancellationToken);
        var deliveredNotifications = await _notificationService.DispatchManyAsync(
            recipientIds.Select(recipientId => new UserNotificationRequest(
                recipientId,
                UserNotificationType.AdminMessage,
                $"admin-campaign:{campaign.Id:N}:user:{recipientId}",
                Title: campaign.Title,
                Message: campaign.Message,
                Source: UserNotificationSource.Admin,
                AdminCampaignId: campaign.Id,
                CreatedByAdminUserId: adminUserId)),
            cancellationToken);
        var delivered = deliveredNotifications.Count;

        campaign.TargetCount = delivered;
        await AddAuditAsync(
            adminUserId,
            scope == AdminNotificationRecipientScope.AllUsers
                ? AdminAuditAction.BroadcastNotificationSent
                : AdminAuditAction.ManualNotificationSent,
            "AdminNotificationCampaign",
            campaign.Id.ToString("N"),
            $"Scope {scope}; category {category}; recipients {delivered}",
            cancellationToken);

        return MapCampaign(campaign);
    }

    public async Task<AdminPageDto<AdminNotificationCampaignDto>> GetNotificationHistoryAsync(
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        (page, pageSize) = NormalizePage(page, pageSize);
        var result = await _adminRepository.GetCampaignsAsync(page, pageSize, cancellationToken);
        return new AdminPageDto<AdminNotificationCampaignDto>
        {
            Items = result.Items.Select(MapCampaign).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = result.TotalCount
        };
    }

    public async Task<AdminPageDto<AdminNotificationHistoryItemDto>> GetNotificationDeliveriesAsync(
        AdminNotificationHistoryQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var source = ParseOptionalEnum<UserNotificationSource>(query.Source, nameof(query.Source));
        var type = ParseOptionalEnum<UserNotificationType>(query.Type, nameof(query.Type));
        var (page, pageSize) = NormalizePage(query.Page, query.PageSize);
        var result = await _adminRepository.GetNotificationsAsync(
            source,
            type,
            query.UserId,
            query.IsRead,
            page,
            pageSize,
            cancellationToken);

        return new AdminPageDto<AdminNotificationHistoryItemDto>
        {
            Items = result.Items.Select(notification => new AdminNotificationHistoryItemDto
            {
                Id = notification.Id,
                UserId = notification.UserId,
                UserEmail = notification.User.Email,
                Source = notification.Source.ToString(),
                Type = notification.Type.ToString(),
                Title = notification.Title,
                Message = notification.Message,
                ResourceLabel = notification.ResourceLabel,
                ReservationId = notification.ReservationId,
                SupportConversationId = notification.SupportConversationId,
                AdminCampaignId = notification.AdminCampaignId,
                CreatedByAdminUserId = notification.CreatedByAdminUserId,
                CreatedAt = notification.CreatedAt,
                ReadAt = notification.ReadAt
            }).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = result.TotalCount
        };
    }

    public async Task<AdminPageDto<AdminOrderDto>> GetReservationsAsync(
        AdminReservationQueryDto query,
        CancellationToken cancellationToken = default)
    {
        var (page, pageSize) = NormalizePage(query.Page, query.PageSize);
        var assignmentFilter = ParseAssignmentFilter(query.AssignmentStatus);
        var result = await _adminRepository.GetReservationsAsync(
            query.Query,
            query.Status,
            assignmentFilter,
            _timeProvider.GetUtcNow().UtcDateTime,
            page,
            pageSize,
            cancellationToken);

        return new AdminPageDto<AdminOrderDto>
        {
            Items = result.Items.Select(MapReservation).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = result.TotalCount
        };
    }

    public async Task<AdminReservationDetailDto> GetReservationAsync(
        int reservationId,
        CancellationToken cancellationToken = default)
    {
        var reservation = await _reservationRepository.GetByIdAsync(reservationId, cancellationToken)
            ?? throw new KeyNotFoundException("Reservation not found.");
        return MapReservationDetail(reservation);
    }

    public async Task<AdminOrderDto> CancelReservationAsync(
        int adminUserId,
        int reservationId,
        CancellationToken cancellationToken = default)
    {
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;

        var reservation = await _adminRepository.TryCancelReservationAsync(
            reservationId,
            nowUtc,
            cancellationToken);
        if (reservation is null)
        {
            throw new ApiException(
                "ADMIN_RESERVATION_TRANSITION_INVALID",
                "This reservation can no longer be cancelled.",
                StatusCodes.Status409Conflict);
        }

        await _notificationService.DispatchAsync(
            new UserNotificationRequest(
                reservation.UserId,
                UserNotificationType.ReservationCancelled,
                $"reservation:{reservation.Id}:admin-cancelled",
                reservation.Server.GPU == "None" ? reservation.Server.CPU : reservation.Server.GPU,
                reservation.Id,
                EventTime: nowUtc),
            cancellationToken);

        await AddAuditAsync(
            adminUserId,
            AdminAuditAction.ReservationCancelled,
            "Reservation",
            reservation.Id.ToString(),
            $"User #{reservation.UserId}; server #{reservation.ServerId}",
            cancellationToken);

        return MapReservation(reservation);
    }

    public async Task<AdminUserOverviewDto> GetUserOverviewAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var user = await _adminRepository.GetUserAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User not found.");
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var counts = await _adminRepository.GetUserCountsAsync(userId, nowUtc, cancellationToken);
        var reservations = await _adminRepository.GetRecentReservationsForUserAsync(userId, 8, cancellationToken);

        return new AdminUserOverviewDto
        {
            Id = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role.ToString(),
            IsEmailVerified = user.IsEmailVerified,
            EmailVerifiedAt = user.EmailVerifiedAt,
            CreatedAt = user.CreatedAt,
            ReservationCount = counts.Reservations,
            ActiveReservationCount = counts.ActiveReservations,
            CompletedPaymentCount = counts.CompletedPayments,
            SupportConversationCount = counts.SupportConversations,
            UnreadNotificationCount = counts.UnreadNotifications,
            RecentReservations = reservations.Select(MapReservation).ToList()
        };
    }

    public async Task<AdminPageDto<AdminUserDto>> SearchUsersAsync(
        string? query,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        (page, pageSize) = NormalizePage(page, pageSize);
        var result = await _adminRepository.SearchUsersAsync(query, page, pageSize, cancellationToken);
        return new AdminPageDto<AdminUserDto>
        {
            Items = result.Items.Select(MapUser).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = result.TotalCount
        };
    }

    public async Task<AdminPageDto<AdminNotificationRecipientDto>> SearchNotificationRecipientsAsync(
        string? query,
        int page,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 20);
        var result = await _adminRepository.SearchNotificationRecipientsAsync(query, page, pageSize, cancellationToken);
        return new AdminPageDto<AdminNotificationRecipientDto>
        {
            Items = result.Items.Select(user => new AdminNotificationRecipientDto
            {
                Id = user.Id,
                FullName = user.FullName,
                Email = user.Email
            }).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = result.TotalCount
        };
    }

    public async Task<AdminUserDto> CreateAdminAsync(
        int actingAdminUserId,
        CreateAdminAccountDto request,
        CancellationToken cancellationToken = default)
    {
        var nowUtc = _timeProvider.GetUtcNow().UtcDateTime;
        var user = new User
        {
            FullName = request.FullName.Trim(),
            Email = EmailAddressNormalizer.Normalize(request.Email),
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            Role = UserRole.Admin,
            CreatedAt = nowUtc,
            IsEmailVerified = true,
            EmailVerifiedAt = nowUtc
        };

        var created = await _adminRepository.TryCreateAdminAsync(
            user,
            actingAdminUserId,
            nowUtc,
            cancellationToken);
        if (created is null)
        {
            throw new ApiException(
                ApiErrorCodes.EmailAlreadyExists,
                "An account with this email already exists.",
                StatusCodes.Status409Conflict);
        }

        return MapUser(created);
    }

    public async Task<IReadOnlyList<AdminAuditEventDto>> GetRecentAuditEventsAsync(
        int take,
        CancellationToken cancellationToken = default)
    {
        var events = await _adminRepository.GetRecentAuditEventsAsync(Math.Clamp(take, 1, 50), cancellationToken);
        return events.Select(item => new AdminAuditEventDto
        {
            Id = item.Id,
            AdminUserId = item.AdminUserId,
            Action = item.Action.ToString(),
            EntityType = item.EntityType,
            EntityId = item.EntityId,
            Details = item.Details,
            CreatedAt = item.CreatedAt
        }).ToList();
    }

    private async Task AddAuditAsync(
        int adminUserId,
        AdminAuditAction action,
        string entityType,
        string entityId,
        string? details,
        CancellationToken cancellationToken)
    {
        await _adminRepository.AddAuditEventAsync(new AdminAuditEvent
        {
            Id = Guid.NewGuid(),
            AdminUserId = adminUserId,
            Action = action,
            EntityType = entityType,
            EntityId = entityId,
            Details = details,
            CreatedAt = _timeProvider.GetUtcNow().UtcDateTime
        }, cancellationToken);
        await _adminRepository.SaveChangesAsync(cancellationToken);
    }

    private static AdminMaintenanceWindowDto MapMaintenanceWindow(ServerMaintenanceWindow window) => new()
    {
        Id = window.Id,
        ServerId = window.ServerId,
        StartTime = window.StartTime,
        EndTime = window.EndTime,
        Reason = window.Reason,
        CreatedAt = window.CreatedAt
    };

    private static AdminUserDto MapUser(User user) => new()
    {
        Id = user.Id,
        FullName = user.FullName,
        Email = user.Email,
        Role = user.Role.ToString(),
        CreatedAt = user.CreatedAt,
        IsEmailVerified = user.IsEmailVerified
    };

    private static AdminNotificationCampaignDto MapCampaign(AdminNotificationCampaign campaign) => new()
    {
        Id = campaign.Id,
        CreatedByAdminUserId = campaign.CreatedByAdminUserId,
        RecipientScope = campaign.RecipientScope.ToString(),
        RecipientUserId = campaign.RecipientUserId,
        RecipientEmail = campaign.RecipientUser?.Email,
        Title = campaign.Title,
        Message = campaign.Message,
        Category = campaign.Category,
        TargetCount = campaign.TargetCount,
        CreatedAt = campaign.CreatedAt
    };

    private static AdminOrderDto MapReservation(Reservation reservation)
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

    private static AdminReservationDetailDto MapReservationDetail(Reservation reservation)
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

    private static bool HasAssignedCredentials(Reservation reservation) =>
        !string.IsNullOrWhiteSpace(reservation.AssignedIp)
        && !string.IsNullOrWhiteSpace(reservation.AssignedUsername)
        && !string.IsNullOrWhiteSpace(reservation.AssignedPassword);

    private static AdminAssignmentFilter? ParseAssignmentFilter(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value.Trim().Equals("All", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        if (Enum.TryParse<AdminAssignmentFilter>(value.Trim(), true, out var parsed)
            && Enum.IsDefined(parsed))
        {
            return parsed;
        }

        throw ValidationError(
            nameof(AdminReservationQueryDto.AssignmentStatus),
            "AssignmentStatus must be All, NeedsAssignment, or Assigned.");
    }

    private static (int Page, int PageSize) NormalizePage(int page, int pageSize)
    {
        return (Math.Max(page, 1), Math.Clamp(pageSize, 1, 100));
    }

    private static IReadOnlyList<int>? ValidateRecipientSelection(
        AdminNotificationRecipientScope scope,
        AdminSendNotificationDto request)
    {
        var suppliedIds = request.UserIds ?? [];
        var selectedIds = suppliedIds
            .Where(id => id > 0)
            .Distinct()
            .ToList();

        if (scope == AdminNotificationRecipientScope.AllUsers)
        {
            if (request.UserId.HasValue || suppliedIds.Count > 0)
            {
                throw ValidationError(nameof(request.UserIds), "Broadcast requests cannot include selected users.");
            }
            if (!request.ConfirmBroadcast)
            {
                throw new ApiException(
                    "ADMIN_BROADCAST_CONFIRMATION_REQUIRED",
                    "Broadcast notifications require explicit confirmation.",
                    StatusCodes.Status409Conflict);
            }
            return null;
        }

        if (request.ConfirmBroadcast)
        {
            throw ValidationError(nameof(request.ConfirmBroadcast), "Targeted notifications cannot confirm a broadcast.");
        }

        if (scope == AdminNotificationRecipientScope.User)
        {
            if (!request.UserId.HasValue || request.UserId.Value <= 0 || suppliedIds.Count > 0)
            {
                throw ValidationError(nameof(request.UserId), "UserId is required for a single-user notification.");
            }
            return [request.UserId.Value];
        }

        if (request.UserId.HasValue || suppliedIds.Count == 0 || selectedIds.Count != suppliedIds.Distinct().Count())
        {
            throw ValidationError(nameof(request.UserIds), "At least one valid selected user is required.");
        }
        if (selectedIds.Count > 100)
        {
            throw ValidationError(nameof(request.UserIds), "A maximum of 100 users may be selected.");
        }
        return selectedIds;
    }

    private static DateTime NormalizeUtc(DateTime value)
    {
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
    }

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    private static TEnum? ParseOptionalEnum<TEnum>(string? value, string fieldName)
        where TEnum : struct, Enum
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (!Enum.TryParse<TEnum>(value.Trim(), true, out var parsed)
            || !Enum.IsDefined(parsed))
        {
            throw ValidationError(fieldName, $"{fieldName} is invalid.");
        }

        return parsed;
    }

    private static ValidationException ValidationError(string fieldName, string message)
    {
        return new ValidationException([new ValidationFailure(fieldName, message)]);
    }
}
