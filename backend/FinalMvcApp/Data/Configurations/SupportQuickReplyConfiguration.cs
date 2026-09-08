using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportQuickReplyConfiguration : IEntityTypeConfiguration<SupportQuickReply>
{
    public void Configure(EntityTypeBuilder<SupportQuickReply> builder)
    {
        builder.ToTable("SupportQuickReplies");
        builder.HasKey(quickReply => quickReply.Id);

        builder.Property(quickReply => quickReply.Title).IsRequired().HasMaxLength(120);
        builder.Property(quickReply => quickReply.Content).IsRequired().HasMaxLength(2000);
        builder.Property(quickReply => quickReply.Category).HasMaxLength(80);
        builder.Property(quickReply => quickReply.CreatedAt).IsRequired();
        builder.Property(quickReply => quickReply.UpdatedAt).IsRequired();

        builder.HasIndex(quickReply => new { quickReply.IsActive, quickReply.SortOrder, quickReply.Title });
    }
}
