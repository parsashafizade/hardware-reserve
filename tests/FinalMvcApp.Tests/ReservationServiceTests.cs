using FinalMvcApp.DTOs.Reservations;
using FinalMvcApp.Errors;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;

namespace FinalMvcApp.Tests;

public class ReservationServiceTests
{
    [Fact]
    public async Task CreateAsync_WhenReservationOverlaps_ThrowsInvalidOperationException()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);

        var user = new User
        {
            FullName = "Test User",
            Email = "user@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };

        var server = new Server
        {
            CPU = "CPU",
            GPU = "GPU",
            RAM = "32GB",
            Storage = "1TB",
            OS = "Ubuntu 22.04",
            PricePerHour = 45_000m,
            PricePerDay = 810_000m,
            IsActive = true
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();

        var existingStart = DateTime.UtcNow.AddDays(1).AddHours(2);
        var existingEnd = existingStart.AddHours(4);

        await dbContext.Reservations.AddAsync(new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = existingStart,
            EndTime = existingEnd,
            TotalPrice = 180_000m,
            Status = ReservationStatus.Paid
        });
        await dbContext.SaveChangesAsync();

        var request = new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = existingStart.AddHours(1),
            EndTime = existingStart.AddHours(2)
        };

        var action = async () => await service.CreateAsync(user.Id, request);

        var exception = await Assert.ThrowsAsync<ApiException>(action);
        Assert.Equal(ApiErrorCodes.ReservationTimeConflict, exception.Code);
        Assert.Equal(409, exception.StatusCode);
    }

    [Fact]
    public async Task QuoteAsync_ReturnsAuthoritativePriceAndCreateUsesSameTotal()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (user, server) = await SeedUserAndServerAsync(dbContext);
        var start = DateTime.UtcNow.AddDays(2);
        var request = new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(30)
        };

        var quote = await service.QuoteAsync(request);
        request.QuotedTotalPrice = quote.TotalPrice;
        var created = await service.CreateAsync(user.Id, request);

        Assert.True(quote.IsAvailable);
        Assert.Equal("DailyAndHourly", quote.PricingMode);
        Assert.Equal(1_800_000m, quote.TotalPrice);
        Assert.Equal(quote.TotalPrice, created.TotalPrice);
    }

    [Fact]
    public async Task QuoteAsync_WhenWindowOverlaps_ReturnsUnavailableWithoutCreatingReservation()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (user, server) = await SeedUserAndServerAsync(dbContext);
        var start = DateTime.UtcNow.AddDays(2);
        await dbContext.Reservations.AddAsync(new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(4),
            TotalPrice = 300_000m,
            Status = ReservationStatus.Paid
        });
        await dbContext.SaveChangesAsync();

        var quote = await service.QuoteAsync(new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start.AddHours(1),
            EndTime = start.AddHours(3)
        });

        Assert.False(quote.IsAvailable);
        Assert.Single(dbContext.Reservations);
    }

    [Fact]
    public async Task CreateAsync_WhenWindowTouchesExistingBoundary_Succeeds()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (user, server) = await SeedUserAndServerAsync(dbContext);
        var existingStart = DateTime.UtcNow.AddDays(2);
        var existingEnd = existingStart.AddHours(4);
        await dbContext.Reservations.AddAsync(new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = existingStart,
            EndTime = existingEnd,
            TotalPrice = 300_000m,
            Status = ReservationStatus.Paid
        });
        await dbContext.SaveChangesAsync();

        var result = await service.CreateAsync(user.Id, new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = existingEnd,
            EndTime = existingEnd.AddHours(2)
        });

        Assert.True(result.ReservationId > 0);
        Assert.Equal(2, dbContext.Reservations.Count());
    }

    [Fact]
    public async Task CreateAsync_WhenOnlyCancelledWindowOverlaps_Succeeds()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (user, server) = await SeedUserAndServerAsync(dbContext);
        var start = DateTime.UtcNow.AddDays(2);
        await dbContext.Reservations.AddAsync(new Reservation
        {
            UserId = user.Id,
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(4),
            TotalPrice = 300_000m,
            Status = ReservationStatus.Cancelled
        });
        await dbContext.SaveChangesAsync();

        var result = await service.CreateAsync(user.Id, new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start.AddHours(1),
            EndTime = start.AddHours(3)
        });

        Assert.True(result.ReservationId > 0);
    }

    [Fact]
    public async Task CreateAsync_WhenQuotedPriceIsStale_RejectsWithoutCreatingReservation()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (user, server) = await SeedUserAndServerAsync(dbContext);
        var start = DateTime.UtcNow.AddDays(2);

        var exception = await Assert.ThrowsAsync<ApiException>(() => service.CreateAsync(user.Id, new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(4),
            QuotedTotalPrice = 1m
        }));

        Assert.Equal(ApiErrorCodes.ReservationQuoteChanged, exception.Code);
        Assert.Empty(dbContext.Reservations);
    }

    [Fact]
    public async Task QuoteAsync_WhenStartIsPast_RejectsRequest()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (_, server) = await SeedUserAndServerAsync(dbContext);
        var start = DateTime.UtcNow.AddHours(-2);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.QuoteAsync(new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(1)
        }));
    }

    [Fact]
    public async Task QuoteAsync_WhenServerIsInactive_RejectsRequest()
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);
        var (_, server) = await SeedUserAndServerAsync(dbContext, isActive: false);
        var start = DateTime.UtcNow.AddDays(2);

        await Assert.ThrowsAsync<KeyNotFoundException>(() => service.QuoteAsync(new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = start.AddHours(2)
        }));
    }

    [Theory]
    [InlineData(3, 225_000)]
    [InlineData(5.5, 412_500)]
    [InlineData(24, 1_350_000)]
    [InlineData(30, 1_800_000)]
    [InlineData(48, 2_700_000)]
    [InlineData(120, 6_750_000)]
    public async Task CreateAsync_UsesHourlyAndDailyTomanPricing(
        double durationHours,
        long expectedTotal)
    {
        var total = await CreateReservationAndGetTotalAsync(
            pricePerHour: 75_000m,
            pricePerDay: 1_350_000m,
            durationHours: durationHours);

        Assert.Equal((decimal)expectedTotal, total);
    }

    [Fact]
    public async Task CreateAsync_WhenPriceProducesFractionalToman_RoundsAwayFromZero()
    {
        var total = await CreateReservationAndGetTotalAsync(
            pricePerHour: 12_001m,
            pricePerDay: 216_018m,
            durationHours: 0.5);

        Assert.Equal(6_001m, total);
    }

    private static async Task<decimal> CreateReservationAndGetTotalAsync(
        decimal pricePerHour,
        decimal pricePerDay,
        double durationHours)
    {
        await using var dbContext = TestDbFactory.Create();
        var service = BuildService(dbContext);

        var user = new User
        {
            FullName = "Test User",
            Email = $"price-{Guid.NewGuid():N}@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };

        var server = new Server
        {
            CPU = "CPU",
            GPU = "GPU",
            RAM = "64GB",
            Storage = "2TB",
            OS = "Ubuntu 24.04",
            PricePerHour = pricePerHour,
            PricePerDay = pricePerDay,
            IsActive = true
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();

        var start = DateTime.UtcNow.AddDays(2);
        var end = start.AddHours(durationHours);
        var request = new CreateReservationDto
        {
            ServerId = server.Id,
            StartTime = start,
            EndTime = end
        };

        var result = await service.CreateAsync(user.Id, request);

        return result.TotalPrice;
    }

    private static ReservationService BuildService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var reservationRepository = new ReservationRepository(dbContext);
        var userRepository = new UserRepository(dbContext);
        var serverRepository = new ServerRepository(dbContext);

        return new ReservationService(
            reservationRepository,
            userRepository,
            serverRepository,
            new RecordingUserNotificationService(),
            TimeProvider.System);
    }

    private static async Task<(User User, Server Server)> SeedUserAndServerAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        bool isActive = true)
    {
        var user = new User
        {
            FullName = "Reservation Test User",
            Email = $"reservation-{Guid.NewGuid():N}@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };
        var server = new Server
        {
            CPU = "AMD EPYC",
            GPU = "NVIDIA A100",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 75_000m,
            PricePerDay = 1_350_000m,
            IsActive = isActive
        };

        await dbContext.Users.AddAsync(user);
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();
        return (user, server);
    }
}
