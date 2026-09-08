using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;

namespace FinalMvcApp.Tests;

public class ReservationCockpitTests
{
    [Fact]
    public async Task GetCockpitAsync_ReturnsOwnedPaidReservationAndIntendedAccessDetails()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "cockpit-owner@test.local");
        var server = await AddServerAsync(dbContext);
        var reservation = new Reservation
        {
            UserId = owner.Id,
            ServerId = server.Id,
            StartTime = DateTime.UtcNow.AddHours(1),
            EndTime = DateTime.UtcNow.AddHours(5),
            TotalPrice = 300_000m,
            Status = ReservationStatus.Paid,
            AssignedIp = "203.0.113.10",
            AssignedUsername = "customer",
            AssignedPassword = "assigned-secret",
            Payment = new Payment
            {
                Amount = 300_000m,
                PaymentDate = DateTime.UtcNow,
                Status = PaymentStatus.Completed
            }
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();
        var service = BuildService(dbContext);

        var cockpit = await service.GetCockpitAsync(owner.Id, reservation.Id);

        Assert.Equal(reservation.Id, cockpit.ReservationId);
        Assert.Equal("203.0.113.10", cockpit.AssignedIp);
        Assert.Equal("customer", cockpit.AssignedUsername);
        Assert.Equal("assigned-secret", cockpit.AssignedPassword);
        Assert.Equal("Completed", cockpit.PaymentStatus);
        Assert.NotNull(cockpit.PaymentId);
    }

    [Fact]
    public async Task GetCockpitAsync_DoesNotRevealAnotherUsersReservation()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "cockpit-a@test.local");
        var other = await SupportTestFactory.AddUserAsync(dbContext, "cockpit-b@test.local");
        var server = await AddServerAsync(dbContext);
        var reservation = new Reservation
        {
            UserId = owner.Id,
            ServerId = server.Id,
            StartTime = DateTime.UtcNow.AddHours(2),
            EndTime = DateTime.UtcNow.AddHours(4),
            TotalPrice = 150_000m,
            Status = ReservationStatus.PendingPayment,
            AssignedIp = "203.0.113.11",
            AssignedUsername = "hidden",
            AssignedPassword = "hidden"
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();
        var service = BuildService(dbContext);

        await Assert.ThrowsAsync<KeyNotFoundException>(() =>
            service.GetCockpitAsync(other.Id, reservation.Id));
    }

    [Fact]
    public async Task GetCockpitAsync_WithholdsAccessDetailsUntilReservationIsPaid()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "cockpit-pending@test.local");
        var server = await AddServerAsync(dbContext);
        var reservation = new Reservation
        {
            UserId = owner.Id,
            ServerId = server.Id,
            StartTime = DateTime.UtcNow.AddHours(2),
            EndTime = DateTime.UtcNow.AddHours(4),
            TotalPrice = 150_000m,
            Status = ReservationStatus.PendingPayment,
            AssignedIp = "203.0.113.12",
            AssignedUsername = "not-yet-visible",
            AssignedPassword = "not-yet-visible"
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();

        var cockpit = await BuildService(dbContext).GetCockpitAsync(owner.Id, reservation.Id);

        Assert.Null(cockpit.AssignedIp);
        Assert.Null(cockpit.AssignedUsername);
        Assert.Null(cockpit.AssignedPassword);
    }

    private static ReservationService BuildService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        return new ReservationService(
            new ReservationRepository(dbContext),
            new UserRepository(dbContext),
            new ServerRepository(dbContext),
            new RecordingUserNotificationService(),
            TimeProvider.System);
    }

    private static async Task<Server> AddServerAsync(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        var server = new Server
        {
            CPU = "AMD EPYC",
            GPU = "NVIDIA A100",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 75_000m,
            PricePerDay = 1_350_000m,
            IsActive = true
        };
        await dbContext.Servers.AddAsync(server);
        await dbContext.SaveChangesAsync();
        return server;
    }
}
