using FinalMvcApp.DTOs.Export;
using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.Interfaces;
using FinalMvcApp.Utils;
using Microsoft.AspNetCore.Http;
using System.Globalization;
using System.Text;

namespace FinalMvcApp.Services.Implementations;

public class ReservationService : IReservationService
{
    private readonly IReservationRepository _reservationRepository;
    private readonly IUserRepository _userRepository;
    private readonly IServerRepository _serverRepository;
    private readonly IUserNotificationService _notificationService;
    private readonly TimeProvider _timeProvider;

    public ReservationService(
        IReservationRepository reservationRepository,
        IUserRepository userRepository,
        IServerRepository serverRepository,
        IUserNotificationService notificationService,
        TimeProvider timeProvider)
    {
        _reservationRepository = reservationRepository;
        _userRepository = userRepository;
        _serverRepository = serverRepository;
        _notificationService = notificationService;
        _timeProvider = timeProvider;
    }

    public async Task<CreateReservationResultDto> CreateAsync(int userId, CreateReservationDto dto, CancellationToken cancellationToken = default)
    {
        _ = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new KeyNotFoundException("User not found.");

        var server = await _serverRepository.GetActiveByIdAsync(dto.ServerId, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found or inactive.");

        var (startTimeUtc, endTimeUtc, duration) = NormalizeAndValidateWindow(dto);
        var totalPrice = CalculatePrice(duration, server.PricePerHour, server.PricePerDay);

        if (dto.QuotedTotalPrice.HasValue && dto.QuotedTotalPrice.Value != totalPrice)
        {
            throw new ApiException(
                ApiErrorCodes.ReservationQuoteChanged,
                "The reservation price changed. Review the updated quote before confirming.",
                StatusCodes.Status409Conflict);
        }

        var reservation = new Reservation
        {
            UserId = userId,
            ServerId = server.Id,
            StartTime = startTimeUtc,
            EndTime = endTimeUtc,
            TotalPrice = totalPrice,
            Status = ReservationStatus.PendingPayment
        };

        if (!await _reservationRepository.TryAddIfAvailableAsync(reservation, cancellationToken))
        {
            throw new ApiException(
                ApiErrorCodes.ReservationTimeConflict,
                "This server is already reserved in the selected time range.",
                StatusCodes.Status409Conflict);
        }

        await _notificationService.DispatchAsync(
            new UserNotificationRequest(
                userId,
                UserNotificationType.ReservationCreated,
                $"reservation:{reservation.Id}:created",
                ServerLabel.For(server),
                reservation.Id,
                EventTime: reservation.StartTime),
            CancellationToken.None);

        return new CreateReservationResultDto
        {
            ReservationId = reservation.Id,
            TotalPrice = reservation.TotalPrice,
            DurationSummary = BuildDurationSummary(duration)
        };
    }

    public async Task<ReservationQuoteResultDto> QuoteAsync(
        CreateReservationDto dto,
        CancellationToken cancellationToken = default)
    {
        var server = await _serverRepository.GetActiveByIdAsync(dto.ServerId, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found or inactive.");

        var (startTimeUtc, endTimeUtc, duration) = NormalizeAndValidateWindow(dto);
        var isAvailable = !await _reservationRepository.HasAvailabilityConflictAsync(
            dto.ServerId,
            startTimeUtc,
            endTimeUtc,
            cancellationToken: cancellationToken);

        return new ReservationQuoteResultDto
        {
            ServerId = server.Id,
            StartTime = startTimeUtc,
            EndTime = endTimeUtc,
            DurationHours = Math.Round(
                (decimal)duration.TotalHours,
                2,
                MidpointRounding.AwayFromZero),
            TotalPrice = CalculatePrice(duration, server.PricePerHour, server.PricePerDay),
            PricingMode = GetPricingMode(duration),
            IsAvailable = isAvailable
        };
    }

    public async Task<ReservationSuggestionResultDto> SuggestAsync(ReservationSuggestionRequestDto request, CancellationToken cancellationToken = default)
    {
        var server = await _serverRepository.GetActiveByIdAsync(request.ServerId, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found or inactive.");

        _ = server;

        var nowUtc = DateTime.UtcNow;
        var searchLimitUtc = nowUtc.AddDays(30);
        var duration = TimeSpan.FromHours((double)request.DesiredDurationHours);

        if (server.OperationalStatus != ServerOperationalStatus.Available)
        {
            return new ReservationSuggestionResultDto
            {
                Message = "Server is not currently available for reservations."
            };
        }

        var reservations = await _reservationRepository.GetAvailabilityBlocksAsync(
            request.ServerId,
            nowUtc,
            searchLimitUtc,
            cancellationToken);

        var candidateStart = nowUtc;

        foreach (var reservation in reservations)
        {
            if (reservation.EndTime <= candidateStart)
            {
                continue;
            }

            if (candidateStart + duration <= reservation.StartTime)
            {
                return new ReservationSuggestionResultDto
                {
                    SuggestedStart = candidateStart,
                    SuggestedEnd = candidateStart + duration,
                    Message = "Found earliest available slot."
                };
            }

            if (candidateStart < reservation.EndTime)
            {
                candidateStart = reservation.EndTime;
            }
        }

        if (candidateStart + duration <= searchLimitUtc)
        {
            return new ReservationSuggestionResultDto
            {
                SuggestedStart = candidateStart,
                SuggestedEnd = candidateStart + duration,
                Message = "Found earliest available slot."
            };
        }

        return new ReservationSuggestionResultDto
        {
            Message = "Server is fully booked for the next 30 days."
        };
    }

    public async Task<IReadOnlyList<ReservationBusySlotDto>> GetBusySlotsAsync(
        int serverId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default)
    {
        _ = await _serverRepository.GetActiveByIdAsync(serverId, cancellationToken)
            ?? throw new KeyNotFoundException("Server not found or inactive.");

        var normalizedFromUtc = NormalizeToUtc(fromUtc);
        var normalizedToUtc = NormalizeToUtc(toUtc);

        if (normalizedToUtc <= normalizedFromUtc)
        {
            throw new InvalidOperationException("toUtc must be greater than fromUtc.");
        }

        var reservations = await _reservationRepository.GetAvailabilityBlocksAsync(
            serverId,
            normalizedFromUtc,
            normalizedToUtc,
            cancellationToken);

        return reservations
            .Select(reservation => new ReservationBusySlotDto
            {
                ReservationId = reservation.ReservationId,
                StartTime = reservation.StartTime,
                EndTime = reservation.EndTime,
                Source = reservation.IsMaintenance ? "Maintenance" : "Reservation"
            })
            .ToList();
    }

    public async Task<IReadOnlyList<MyReservationDto>> GetMyReservationsAsync(int userId, CancellationToken cancellationToken = default)
    {
        var reservations = await _reservationRepository.GetByUserIdAsync(userId, cancellationToken);

        return reservations
            .Select(MapToMyReservationDto)
            .ToList();
    }

    public async Task<MyReservationDto> GetMyReservationByIdAsync(int userId, int reservationId, CancellationToken cancellationToken = default)
    {
        var reservation = await _reservationRepository.GetByIdForUserAsync(
                reservationId,
                userId,
                cancellationToken)
            ?? throw new KeyNotFoundException("Reservation not found.");

        return MapToMyReservationDto(reservation);
    }

    public async Task<ReservationCockpitDto> GetCockpitAsync(
        int userId,
        int reservationId,
        CancellationToken cancellationToken = default)
    {
        var reservation = await _reservationRepository.GetByIdForUserAsync(
                reservationId,
                userId,
                cancellationToken)
            ?? throw new KeyNotFoundException("Reservation not found.");

        var isPaid = reservation.Status == ReservationStatus.Paid;
        return new ReservationCockpitDto
        {
            ReservationId = reservation.Id,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            Status = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            ServerTimeUtc = _timeProvider.GetUtcNow().UtcDateTime,
            PaymentId = reservation.Payment?.Id,
            PaymentDate = reservation.Payment?.PaymentDate,
            AssignedIp = isPaid ? reservation.AssignedIp : null,
            AssignedUsername = isPaid ? reservation.AssignedUsername : null,
            AssignedPassword = isPaid ? reservation.AssignedPassword : null,
            Server = MapServer(reservation)
        };
    }

    public async Task<IReadOnlyList<MyServiceDto>> GetMyServicesAsync(int userId, CancellationToken cancellationToken = default)
    {
        var reservations = await _reservationRepository.GetPaidByUserIdAsync(userId, cancellationToken);

        return reservations
            .Select(reservation =>
            {
                var credentialsAssigned = !string.IsNullOrWhiteSpace(reservation.AssignedIp)
                    && !string.IsNullOrWhiteSpace(reservation.AssignedUsername)
                    && !string.IsNullOrWhiteSpace(reservation.AssignedPassword);

                return new MyServiceDto
                {
                    ReservationId = reservation.Id,
                    StartTime = reservation.StartTime,
                    EndTime = reservation.EndTime,
                    TotalPrice = reservation.TotalPrice,
                    Server = new ServerSpecsDto
                    {
                        ServerId = reservation.ServerId,
                        CPU = reservation.Server.CPU,
                        GPU = reservation.Server.GPU,
                        RAM = reservation.Server.RAM,
                        Storage = reservation.Server.Storage,
                        OS = reservation.Server.OS
                    },
                    AssignedIp = reservation.AssignedIp,
                    AssignedUsername = reservation.AssignedUsername,
                    AssignedPassword = reservation.AssignedPassword,
                    Message = credentialsAssigned ? null : "Credentials not assigned yet."
                };
            })
            .ToList();
    }

    public async Task<FileResultDto> ExportMyReservationsCsvAsync(int userId, CancellationToken cancellationToken = default)
    {
        var reservations = await _reservationRepository.GetByUserIdAsync(userId, cancellationToken);
        var builder = new StringBuilder();

        builder.AppendLine("ReservationId,ServerId,CPU,GPU,RAM,Storage,OS,StartTimeUtc,EndTimeUtc,TotalPrice,Status,PaymentStatus");

        foreach (var reservation in reservations)
        {
            var paymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid";
            builder.AppendLine(string.Join(',',
                reservation.Id,
                reservation.ServerId,
                EscapeCsv(reservation.Server.CPU),
                EscapeCsv(reservation.Server.GPU),
                EscapeCsv(reservation.Server.RAM),
                EscapeCsv(reservation.Server.Storage),
                EscapeCsv(reservation.Server.OS),
                reservation.StartTime.ToString("O"),
                reservation.EndTime.ToString("O"),
                reservation.TotalPrice.ToString(CultureInfo.InvariantCulture),
                EscapeCsv(reservation.Status.ToString()),
                EscapeCsv(paymentStatus)));
        }

        return new FileResultDto
        {
            Content = Encoding.UTF8.GetBytes(builder.ToString()),
            ContentType = "text/csv",
            FileName = $"my-reservations-{DateTime.UtcNow:yyyyMMddHHmmss}.csv"
        };
    }

    private static decimal CalculatePrice(TimeSpan duration, decimal pricePerHour, decimal pricePerDay)
    {
        var totalHours = (decimal)duration.TotalHours;

        if (totalHours < 24)
        {
            return Math.Round(totalHours * pricePerHour, 0, MidpointRounding.AwayFromZero);
        }

        var days = (int)Math.Floor(totalHours / 24);
        var remainingHours = totalHours - (days * 24);

        return Math.Round(
            (days * pricePerDay) + (remainingHours * pricePerHour),
            0,
            MidpointRounding.AwayFromZero);
    }

    private static string GetPricingMode(TimeSpan duration)
    {
        var totalHours = (decimal)duration.TotalHours;
        if (totalHours < 24)
        {
            return "Hourly";
        }

        return totalHours % 24 == 0
            ? "Daily"
            : "DailyAndHourly";
    }

    private static (DateTime StartTimeUtc, DateTime EndTimeUtc, TimeSpan Duration)
        NormalizeAndValidateWindow(CreateReservationDto dto)
    {
        var startTimeUtc = NormalizeToUtc(dto.StartTime);
        var endTimeUtc = NormalizeToUtc(dto.EndTime);

        if (startTimeUtc <= DateTime.UtcNow)
        {
            throw new InvalidOperationException("StartTime must be in the future.");
        }

        if (endTimeUtc <= startTimeUtc)
        {
            throw new InvalidOperationException("EndTime must be greater than StartTime.");
        }

        return (startTimeUtc, endTimeUtc, endTimeUtc - startTimeUtc);
    }

    private static string BuildDurationSummary(TimeSpan duration)
    {
        var totalHours = (decimal)duration.TotalHours;
        var days = (int)Math.Floor(totalHours / 24);
        var remainingHours = totalHours - (days * 24);

        return $"{days} day(s), {Math.Round(remainingHours, 2, MidpointRounding.AwayFromZero)} hour(s)";
    }

    private static string EscapeCsv(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var sanitized = value;
        if (sanitized.StartsWith('=')
            || sanitized.StartsWith('+')
            || sanitized.StartsWith('-')
            || sanitized.StartsWith('@'))
        {
            sanitized = $"'{sanitized}";
        }

        var escaped = sanitized.Replace("\"", "\"\"");
        if (escaped.Contains(',') || escaped.Contains('"') || escaped.Contains('\n') || escaped.Contains('\r'))
        {
            return $"\"{escaped}\"";
        }

        return escaped;
    }

    private static DateTime NormalizeToUtc(DateTime value)
    {
        if (value.Kind == DateTimeKind.Utc)
        {
            return value;
        }

        if (value.Kind == DateTimeKind.Unspecified)
        {
            return DateTime.SpecifyKind(value, DateTimeKind.Utc);
        }

        return value.ToUniversalTime();
    }

    private static MyReservationDto MapToMyReservationDto(Reservation reservation)
    {
        return new MyReservationDto
        {
            ReservationId = reservation.Id,
            StartTime = reservation.StartTime,
            EndTime = reservation.EndTime,
            TotalPrice = reservation.TotalPrice,
            Status = reservation.Status.ToString(),
            PaymentStatus = reservation.Payment?.Status.ToString() ?? "Unpaid",
            Server = MapServer(reservation)
        };
    }

    private static ServerSpecsDto MapServer(Reservation reservation)
    {
        return new ServerSpecsDto
        {
            ServerId = reservation.ServerId,
            CPU = reservation.Server.CPU,
            GPU = reservation.Server.GPU,
            RAM = reservation.Server.RAM,
            Storage = reservation.Server.Storage,
            OS = reservation.Server.OS
        };
    }

}
