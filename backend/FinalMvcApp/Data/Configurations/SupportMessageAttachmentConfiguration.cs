using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportMessageAttachmentConfiguration : IEntityTypeConfiguration<SupportMessageAttachment>
{
    public void Configure(EntityTypeBuilder<SupportMessageAttachment> builder)
    {
        builder.ToTable("SupportMessageAttachments");
        builder.HasKey(attachment => attachment.Id);

        builder.Property(attachment => attachment.FileName).IsRequired().HasMaxLength(255);
        builder.Property(attachment => attachment.ContentType).IsRequired().HasMaxLength(120);
        builder.Property(attachment => attachment.StorageKey).IsRequired().HasMaxLength(500);
        builder.Property(attachment => attachment.CreatedAt).IsRequired();

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_SupportMessageAttachments_SizeBytes",
            "\"SizeBytes\" >= 0"));

        builder.HasOne(attachment => attachment.Message)
            .WithMany(message => message.Attachments)
            .HasForeignKey(attachment => attachment.MessageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(attachment => attachment.MessageId);
        builder.HasIndex(attachment => attachment.StorageKey).IsUnique();
    }
}
