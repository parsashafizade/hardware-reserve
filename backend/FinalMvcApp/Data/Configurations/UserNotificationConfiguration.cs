using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class UserNotificationConfiguration : IEntityTypeConfiguration<UserNotification>
{
    public void Configure(EntityTypeBuilder<UserNotification> builder)
    {
        builder.ToTable("UserNotifications");

        builder.HasKey(notification => notification.Id);

        builder.Property(notification => notification.Type)
            .HasConversion<string>()
            .HasMaxLength(50)
            .IsRequired();

        builder.Property(notification => notification.Source)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(notification => notification.DeduplicationKey)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(notification => notification.ResourceLabel)
            .HasMaxLength(160);

        builder.Property(notification => notification.Title)
            .HasMaxLength(120);

        builder.Property(notification => notification.Message)
            .HasMaxLength(1000);

        builder.Property(notification => notification.CreatedAt)
            .IsRequired();

        builder.HasIndex(notification => notification.DeduplicationKey)
            .IsUnique();

        builder.HasIndex(notification => new
        {
            notification.UserId,
            notification.CreatedAt,
            notification.Id
        });

        builder.HasIndex(notification => new
        {
            notification.UserId,
            notification.ReadAt
        });

        builder.HasOne(notification => notification.User)
            .WithMany(user => user.Notifications)
            .HasForeignKey(notification => notification.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(notification => notification.Reservation)
            .WithMany(reservation => reservation.Notifications)
            .HasForeignKey(notification => notification.ReservationId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(notification => notification.SupportConversation)
            .WithMany(conversation => conversation.Notifications)
            .HasForeignKey(notification => notification.SupportConversationId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(notification => notification.AdminCampaign)
            .WithMany(campaign => campaign.Notifications)
            .HasForeignKey(notification => notification.AdminCampaignId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(notification => notification.CreatedByAdminUser)
            .WithMany()
            .HasForeignKey(notification => notification.CreatedByAdminUserId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(notification => notification.AdminCampaignId);
    }
}
