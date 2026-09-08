using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class ReservationConfiguration : IEntityTypeConfiguration<Reservation>
{
    public void Configure(EntityTypeBuilder<Reservation> builder)
    {
        builder.ToTable("Reservations");

        builder.HasKey(reservation => reservation.Id);

        builder.Property(reservation => reservation.StartTime)
            .IsRequired();

        builder.Property(reservation => reservation.EndTime)
            .IsRequired();

        builder.Property(reservation => reservation.TotalPrice)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(reservation => reservation.Status)
            .HasConversion<string>()
            .HasMaxLength(30)
            .IsRequired();

        builder.Property(reservation => reservation.AssignedIp)
            .HasMaxLength(100);

        builder.Property(reservation => reservation.AssignedUsername)
            .HasMaxLength(100);

        builder.Property(reservation => reservation.AssignedPassword)
            .HasMaxLength(100);

        builder.Property(reservation => reservation.ServiceDetailsVersion)
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(reservation => reservation.ServiceDetailsNotifiedVersion)
            .HasDefaultValue(0)
            .IsRequired();

        builder.Property(reservation => reservation.StartedNotificationDelivered)
            .HasDefaultValue(false)
            .IsRequired();

        builder.Property(reservation => reservation.CompletedNotificationDelivered)
            .HasDefaultValue(false)
            .IsRequired();

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_Reservations_TimeRange",
            "\"StartTime\" < \"EndTime\""));

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_Reservations_ServiceDetailsVersions",
            "\"ServiceDetailsNotifiedVersion\" >= 0 AND \"ServiceDetailsNotifiedVersion\" <= \"ServiceDetailsVersion\""));

        builder.HasOne(reservation => reservation.User)
            .WithMany(user => user.Reservations)
            .HasForeignKey(reservation => reservation.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(reservation => reservation.Server)
            .WithMany(server => server.Reservations)
            .HasForeignKey(reservation => reservation.ServerId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(reservation => reservation.Payment)
            .WithOne(payment => payment.Reservation)
            .HasForeignKey<Payment>(payment => payment.ReservationId);

        builder.HasIndex(reservation => new { reservation.ServerId, reservation.StartTime, reservation.EndTime });

        builder.HasIndex(reservation => reservation.Id)
            .HasDatabaseName("IX_Reservations_PendingServiceDetailsNotification")
            .HasFilter("\"ServiceDetailsVersion\" > \"ServiceDetailsNotifiedVersion\"");

        builder.HasIndex(reservation => reservation.StartTime)
            .HasDatabaseName("IX_Reservations_PendingStartedNotification")
            .HasFilter("\"Status\" = 'Paid' AND NOT \"StartedNotificationDelivered\"");

        builder.HasIndex(reservation => reservation.EndTime)
            .HasDatabaseName("IX_Reservations_PendingCompletedNotification")
            .HasFilter("\"Status\" = 'Paid' AND NOT \"CompletedNotificationDelivered\"");
    }
}
