using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class PasswordResetCodeConfiguration
    : IEntityTypeConfiguration<PasswordResetCode>
{
    public void Configure(EntityTypeBuilder<PasswordResetCode> builder)
    {
        builder.ToTable("PasswordResetCodes");

        builder.HasKey(code => code.Id);

        builder.Property(code => code.CodeHash)
            .IsRequired()
            .HasMaxLength(64);

        builder.Property(code => code.CreatedAt)
            .IsRequired();

        builder.Property(code => code.ExpiresAt)
            .IsRequired();

        builder.Property(code => code.AttemptCount)
            .IsRequired()
            .IsConcurrencyToken();

        builder.Property(code => code.UsedAt)
            .IsConcurrencyToken();

        builder.HasOne(code => code.User)
            .WithMany(user => user.PasswordResetCodes)
            .HasForeignKey(code => code.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(code => code.UserId)
            .IsUnique();
    }
}
