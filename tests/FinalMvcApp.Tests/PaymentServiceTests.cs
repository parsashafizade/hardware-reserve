using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;

namespace FinalMvcApp.Tests;

public class PaymentServiceTests
{
    [Fact]
    public async Task PayReservationAsync_UsesPersistedReservationTotal()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = new User
        {
            FullName = "Payment User",
            Email = "payment@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };
        var server = new Server
        {
            CPU = "AMD EPYC 7543",
            GPU = "NVIDIA RTX 3080 10GB",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 75_000m,
            PricePerDay = 1_350_000m,
            IsActive = true
        };
        var reservation = new Reservation
        {
            User = user,
            Server = server,
            StartTime = DateTime.UtcNow.AddDays(1),
            EndTime = DateTime.UtcNow.AddDays(6),
            TotalPrice = 6_750_000m,
            Status = ReservationStatus.PendingPayment
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();

        var service = new PaymentService(
            new ReservationRepository(dbContext),
            new PaymentRepository(dbContext),
            new RecordingUserNotificationService());

        var result = await service.PayReservationAsync(user.Id, reservation.Id);

        Assert.Equal(6_750_000m, result.Amount);
        Assert.Equal(ReservationStatus.Paid, reservation.Status);
        var payment = Assert.Single(dbContext.Payments);
        Assert.Equal(reservation.TotalPrice, payment.Amount);
    }

    [Fact]
    public async Task PayReservationAsync_WhenSuccessfulResponseWasLost_ReturnsExistingPayment()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = new User
        {
            FullName = "Retry User",
            Email = "payment-retry@test.local",
            PasswordHash = "hash",
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow
        };
        var server = new Server
        {
            CPU = "AMD EPYC 7543",
            GPU = "NVIDIA RTX 3080 10GB",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 75_000m,
            PricePerDay = 1_350_000m,
            IsActive = true
        };
        var reservation = new Reservation
        {
            User = user,
            Server = server,
            StartTime = DateTime.UtcNow.AddDays(1),
            EndTime = DateTime.UtcNow.AddDays(2),
            TotalPrice = 1_350_000m,
            Status = ReservationStatus.PendingPayment
        };
        await dbContext.Reservations.AddAsync(reservation);
        await dbContext.SaveChangesAsync();

        var notifications = new RecordingUserNotificationService();
        var service = new PaymentService(
            new ReservationRepository(dbContext),
            new PaymentRepository(dbContext),
            notifications);

        var first = await service.PayReservationAsync(user.Id, reservation.Id);
        var retry = await service.PayReservationAsync(user.Id, reservation.Id);

        Assert.Equal(first.PaymentId, retry.PaymentId);
        Assert.Equal(first.PaymentDate, retry.PaymentDate);
        Assert.Single(dbContext.Payments);
        Assert.Single(notifications.Requests);
    }
}
