using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class ServerWorkloadCapabilityConfiguration : IEntityTypeConfiguration<ServerWorkloadCapability>
{
    public void Configure(EntityTypeBuilder<ServerWorkloadCapability> builder)
    {
        builder.ToTable("ServerWorkloadCapabilities", table => table.HasCheckConstraint(
            "CK_ServerWorkloadCapabilities_SuitabilityLevel",
            "\"SuitabilityLevel\" BETWEEN 1 AND 5"));

        builder.HasKey(capability => new { capability.ServerId, capability.WorkloadType });

        builder.Property(capability => capability.WorkloadType)
            .HasConversion<string>()
            .HasMaxLength(40);

        builder.Property(capability => capability.SuitabilityLevel)
            .IsRequired();

        builder.HasOne(capability => capability.Server)
            .WithMany(server => server.WorkloadCapabilities)
            .HasForeignKey(capability => capability.ServerId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(capability => capability.WorkloadType);
    }
}
