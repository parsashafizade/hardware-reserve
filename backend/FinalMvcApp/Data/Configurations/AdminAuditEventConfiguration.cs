using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class AdminAuditEventConfiguration : IEntityTypeConfiguration<AdminAuditEvent>
{
    public void Configure(EntityTypeBuilder<AdminAuditEvent> builder)
    {
        builder.ToTable("AdminAuditEvents");

        builder.HasKey(auditEvent => auditEvent.Id);

        builder.Property(auditEvent => auditEvent.Action)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(auditEvent => auditEvent.EntityType)
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(auditEvent => auditEvent.EntityId)
            .HasMaxLength(80)
            .IsRequired();

        builder.Property(auditEvent => auditEvent.Details)
            .HasMaxLength(500);

        builder.HasOne(auditEvent => auditEvent.AdminUser)
            .WithMany()
            .HasForeignKey(auditEvent => auditEvent.AdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(auditEvent => auditEvent.CreatedAt);
        builder.HasIndex(auditEvent => new { auditEvent.EntityType, auditEvent.EntityId });
    }
}
