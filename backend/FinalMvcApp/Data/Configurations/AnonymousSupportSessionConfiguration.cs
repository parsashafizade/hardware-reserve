using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class AnonymousSupportSessionConfiguration : IEntityTypeConfiguration<AnonymousSupportSession>
{
    public void Configure(EntityTypeBuilder<AnonymousSupportSession> builder)
    {
        builder.ToTable("AnonymousSupportSessions");
        builder.HasKey(session => session.Id);

        builder.Property(session => session.TokenHash)
            .IsRequired()
            .HasMaxLength(64);

        builder.Property(session => session.CreatedAt).IsRequired();
        builder.Property(session => session.ExpiresAt).IsRequired();
        builder.Property(session => session.LastSeenAt).IsRequired();

        builder.HasOne(session => session.ClaimedByUser)
            .WithMany()
            .HasForeignKey(session => session.ClaimedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(session => session.TokenHash).IsUnique();
        builder.HasIndex(session => session.ExpiresAt);
    }
}
