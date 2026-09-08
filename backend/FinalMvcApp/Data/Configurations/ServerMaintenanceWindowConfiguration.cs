using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class ServerMaintenanceWindowConfiguration : IEntityTypeConfiguration<ServerMaintenanceWindow>
{
    public void Configure(EntityTypeBuilder<ServerMaintenanceWindow> builder)
    {
        builder.ToTable("ServerMaintenanceWindows", table => table.HasCheckConstraint(
            "CK_ServerMaintenanceWindows_TimeRange",
            "\"StartTime\" < \"EndTime\""));

        builder.HasKey(window => window.Id);

        builder.Property(window => window.Reason)
            .HasMaxLength(300);

        builder.Property(window => window.CreatedAt)
            .IsRequired();

        builder.HasOne(window => window.Server)
            .WithMany(server => server.MaintenanceWindows)
            .HasForeignKey(window => window.ServerId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(window => window.CreatedByAdminUser)
            .WithMany()
            .HasForeignKey(window => window.CreatedByAdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(window => new { window.ServerId, window.StartTime, window.EndTime });
    }
}
