using FinalMvcApp.DTOs.Dashboard;
using FinalMvcApp.Controllers;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.Implementations;
using Microsoft.AspNetCore.Authorization;

namespace FinalMvcApp.Tests;

public class DashboardServiceTests
{
    private static readonly DateTimeOffset Now = new(
        2026,
        8,
        20,
        10,
        0,
        0,
        TimeSpan.Zero);

    [Fact]
    public void UserDashboardController_RequiresAuthentication()
    {
        Assert.NotNull(Attribute.GetCustomAttribute(
            typeof(UserDashboardController),
            typeof(AuthorizeAttribute)));
    }

    [Fact]
    public async Task GetSummaryAsync_NewUserReturnsDiscoveryState()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "dashboard-new@test.local");
        var service = BuildService(dbContext);

        var result = await service.GetSummaryAsync(user.Id);

        Assert.Equal(DashboardPrimaryStates.Discovery, result.PrimaryState);
        Assert.Null(result.PrimaryReservation);
        Assert.Equal(0, result.Metrics.TotalReservations);
        Assert.Equal(Now.UtcDateTime, result.ServerTimeUtc);
    }

    [Fact]
    public async Task GetSummaryAsync_PendingPaymentHasPriorityAndDataIsOwnerScoped()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "dashboard-owner@test.local");
        var other = await SupportTestFactory.AddUserAsync(dbContext, "dashboard-other@test.local");
        var server = await AddServerAsync(dbContext, "NVIDIA H100 80GB");

        dbContext.Reservations.AddRange(
            Reservation(owner.Id, server.Id, Now.AddHours(-1), Now.AddHours(3), ReservationStatus.Paid),
            Reservation(owner.Id, server.Id, Now.AddHours(5), Now.AddHours(9), ReservationStatus.PendingPayment),
            Reservation(other.Id, server.Id, Now.AddHours(1), Now.AddHours(2), ReservationStatus.PendingPayment));
        await dbContext.SaveChangesAsync();

        var result = await BuildService(dbContext).GetSummaryAsync(owner.Id);

        Assert.Equal(DashboardPrimaryStates.PendingPayment, result.PrimaryState);
        Assert.Equal(owner.Id, dbContext.Reservations.Single(item => item.Id == result.PrimaryReservation!.ReservationId).UserId);
        Assert.Equal(2, result.Metrics.TotalReservations);
        Assert.Equal(1, result.Metrics.PendingPayment);
        Assert.Equal(1, result.Metrics.Active);
    }

    [Fact]
    public async Task GetSummaryAsync_UsesActiveUpcomingAndRecentCompletedPriority()
    {
        await using var dbContext = TestDbFactory.Create();
        var user = await SupportTestFactory.AddUserAsync(dbContext, "dashboard-priority@test.local");
        var server = await AddServerAsync(dbContext, "NVIDIA A100 40GB");
        var active = Reservation(user.Id, server.Id, Now.AddHours(-1), Now.AddHours(2), ReservationStatus.Paid);
        var upcoming = Reservation(user.Id, server.Id, Now.AddHours(3), Now.AddHours(5), ReservationStatus.Paid);
        var completed = Reservation(user.Id, server.Id, Now.AddDays(-2), Now.AddDays(-2).AddHours(2), ReservationStatus.Paid);
        dbContext.Reservations.AddRange(active, upcoming, completed);
        await dbContext.SaveChangesAsync();
        var service = BuildService(dbContext);

        var activeResult = await service.GetSummaryAsync(user.Id);
        Assert.Equal(DashboardPrimaryStates.Active, activeResult.PrimaryState);
        Assert.Equal(active.Id, activeResult.PrimaryReservation!.ReservationId);

        active.EndTime = Now.AddMinutes(-1).UtcDateTime;
        await dbContext.SaveChangesAsync();
        var upcomingResult = await service.GetSummaryAsync(user.Id);
        Assert.Equal(DashboardPrimaryStates.Upcoming, upcomingResult.PrimaryState);
        Assert.Equal(upcoming.Id, upcomingResult.PrimaryReservation!.ReservationId);

        upcoming.StartTime = Now.AddMinutes(20).UtcDateTime;
        upcoming.EndTime = Now.AddHours(2).UtcDateTime;
        await dbContext.SaveChangesAsync();
        var startingSoonResult = await service.GetSummaryAsync(user.Id);
        Assert.Equal(DashboardPrimaryStates.StartingSoon, startingSoonResult.PrimaryState);

        upcoming.StartTime = Now.AddMinutes(-30).UtcDateTime;
        upcoming.EndTime = Now.AddMinutes(-10).UtcDateTime;
        await dbContext.SaveChangesAsync();
        var completedResult = await service.GetSummaryAsync(user.Id);
        Assert.Equal(DashboardPrimaryStates.RecentCompleted, completedResult.PrimaryState);
        Assert.Equal(active.Id, completedResult.PrimaryReservation!.ReservationId);
    }

    [Fact]
    public async Task SearchCommandsAsync_ReturnsActiveServersAndOnlyOwnedReservations()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "command-owner@test.local");
        var other = await SupportTestFactory.AddUserAsync(dbContext, "command-other@test.local");
        var activeServer = await AddServerAsync(dbContext, "NVIDIA H100 80GB");
        var inactiveServer = await AddServerAsync(dbContext, "NVIDIA H100 SXM", isActive: false);
        var owned = Reservation(owner.Id, activeServer.Id, Now.AddHours(2), Now.AddHours(4), ReservationStatus.Paid);
        var foreign = Reservation(other.Id, activeServer.Id, Now.AddHours(5), Now.AddHours(7), ReservationStatus.Paid);
        dbContext.Reservations.AddRange(owned, foreign);
        await dbContext.SaveChangesAsync();
        var service = BuildService(dbContext);

        var byHardware = await service.SearchCommandsAsync(owner.Id, new CommandSearchQueryDto
        {
            Query = "H100",
            Limit = 8
        });
        var byForeignId = await service.SearchCommandsAsync(owner.Id, new CommandSearchQueryDto
        {
            Query = $"HR-{foreign.Id}",
            Limit = 8
        });
        var byPersianStatus = await service.SearchCommandsAsync(owner.Id, new CommandSearchQueryDto
        {
            Query = "پرداخت‌شده",
            Limit = 8
        });

        Assert.Contains(byHardware.Servers, item => item.ServerId == activeServer.Id);
        Assert.DoesNotContain(byHardware.Servers, item => item.ServerId == inactiveServer.Id);
        Assert.Single(byHardware.Reservations);
        Assert.Equal(owned.Id, byHardware.Reservations[0].ReservationId);
        Assert.Empty(byForeignId.Reservations);
        Assert.Single(byPersianStatus.Reservations);
        Assert.Equal(owned.Id, byPersianStatus.Reservations[0].ReservationId);
    }

    private static DashboardService BuildService(FinalMvcApp.Data.ApplicationDbContext dbContext)
    {
        return new DashboardService(
            new ReservationRepository(dbContext),
            new ServerRepository(dbContext),
            new DashboardTimeProvider(Now));
    }

    private static async Task<Server> AddServerAsync(
        FinalMvcApp.Data.ApplicationDbContext dbContext,
        string gpu,
        bool isActive = true)
    {
        var server = new Server
        {
            CPU = "AMD EPYC 9654",
            GPU = gpu,
            RAM = "128GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = 260_000m,
            PricePerDay = 4_680_000m,
            IsActive = isActive
        };
        dbContext.Servers.Add(server);
        await dbContext.SaveChangesAsync();
        return server;
    }

    private static Reservation Reservation(
        int userId,
        int serverId,
        DateTimeOffset start,
        DateTimeOffset end,
        ReservationStatus status)
    {
        return new Reservation
        {
            UserId = userId,
            ServerId = serverId,
            StartTime = start.UtcDateTime,
            EndTime = end.UtcDateTime,
            TotalPrice = 1_000_000m,
            Status = status
        };
    }

    private sealed class DashboardTimeProvider : TimeProvider
    {
        private readonly DateTimeOffset _utcNow;

        public DashboardTimeProvider(DateTimeOffset utcNow)
        {
            _utcNow = utcNow;
        }

        public override DateTimeOffset GetUtcNow() => _utcNow;
    }
}
