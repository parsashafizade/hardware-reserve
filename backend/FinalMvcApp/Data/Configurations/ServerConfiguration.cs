using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class ServerConfiguration : IEntityTypeConfiguration<Server>
{
    public void Configure(EntityTypeBuilder<Server> builder)
    {
        builder.ToTable("Servers");

        builder.HasKey(server => server.Id);

        builder.Property(server => server.CPU)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(server => server.GPU)
            .IsRequired()
            .HasMaxLength(120);

        builder.Property(server => server.RAM)
            .IsRequired()
            .HasMaxLength(40);

        builder.Property(server => server.Storage)
            .IsRequired()
            .HasMaxLength(40);

        builder.Property(server => server.OS)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(server => server.PricePerHour)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(server => server.PricePerDay)
            .HasPrecision(18, 2)
            .IsRequired();

        builder.Property(server => server.IsActive)
            .IsRequired();

        builder.Property(server => server.OperationalStatus)
            .HasConversion<string>()
            .HasMaxLength(40)
            .IsRequired();

        builder.Property(server => server.FinderEligible)
            .IsRequired();

        builder.Property(server => server.PerformanceTier)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Servers_CpuCapabilityLevel",
                "\"CpuCapabilityLevel\" BETWEEN 0 AND 100");
            table.HasCheckConstraint(
                "CK_Servers_GpuCapabilityLevel",
                "\"GpuCapabilityLevel\" BETWEEN 0 AND 100");
        });

        builder.HasIndex(server => server.OperationalStatus);
        builder.HasIndex(server => server.FinderEligible);
    }
}
