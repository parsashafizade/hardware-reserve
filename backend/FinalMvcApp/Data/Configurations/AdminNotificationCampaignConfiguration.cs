using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class AdminNotificationCampaignConfiguration : IEntityTypeConfiguration<AdminNotificationCampaign>
{
    public void Configure(EntityTypeBuilder<AdminNotificationCampaign> builder)
    {
        builder.ToTable("AdminNotificationCampaigns");

        builder.HasKey(campaign => campaign.Id);

        builder.Property(campaign => campaign.RecipientScope)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(campaign => campaign.Title)
            .HasMaxLength(120)
            .IsRequired();

        builder.Property(campaign => campaign.Message)
            .HasMaxLength(1000)
            .IsRequired();

        builder.Property(campaign => campaign.Category)
            .HasMaxLength(40)
            .IsRequired();

        builder.HasOne(campaign => campaign.CreatedByAdminUser)
            .WithMany()
            .HasForeignKey(campaign => campaign.CreatedByAdminUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(campaign => campaign.RecipientUser)
            .WithMany()
            .HasForeignKey(campaign => campaign.RecipientUserId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(campaign => campaign.CreatedAt);
        builder.HasIndex(campaign => campaign.RecipientUserId);
    }
}
