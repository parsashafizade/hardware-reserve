using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class PendingEmailChangeConfiguration
    : IEntityTypeConfiguration<PendingEmailChange>
{
    public void Configure(EntityTypeBuilder<PendingEmailChange> builder)
    {
        builder.ToTable("PendingEmailChanges");

        builder.HasKey(change => change.Id);

        builder.Property(change => change.CurrentEmail)
            .IsRequired()
            .HasMaxLength(320);

        builder.Property(change => change.NewEmail)
            .IsRequired()
            .HasMaxLength(320);

        builder.Property(change => change.CurrentCodeHash)
            .IsRequired()
            .HasMaxLength(64)
            .IsConcurrencyToken();

        builder.Property(change => change.NewCodeHash)
            .IsRequired()
            .HasMaxLength(64)
            .IsConcurrencyToken();

        builder.Property(change => change.CurrentAttemptCount)
            .IsConcurrencyToken();

        builder.Property(change => change.NewAttemptCount)
            .IsConcurrencyToken();

        builder.Property(change => change.CurrentCodeUsedAt)
            .IsConcurrencyToken();

        builder.Property(change => change.NewCodeUsedAt)
            .IsConcurrencyToken();

        builder.Property(change => change.CurrentEmailVerifiedAt)
            .IsConcurrencyToken();

        builder.Property(change => change.NewEmailVerifiedAt)
            .IsConcurrencyToken();

        builder.Property(change => change.CompletedAt)
            .IsConcurrencyToken();

        builder.Property(change => change.InvalidatedAt)
            .IsConcurrencyToken();

        builder.HasOne(change => change.User)
            .WithMany()
            .HasForeignKey(change => change.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(change => change.UserId)
            .IsUnique();

        builder.HasIndex(change => change.NewEmail);
    }
}
