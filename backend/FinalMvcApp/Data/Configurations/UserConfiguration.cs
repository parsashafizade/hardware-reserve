using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users");

        builder.HasKey(user => user.Id);

        builder.Property(user => user.FullName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(user => user.Email)
            .IsRequired()
            .HasMaxLength(320);

        builder.Property(user => user.PasswordHash)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(user => user.Role)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(user => user.ProfileImagePath)
            .HasMaxLength(500);

        builder.Property(user => user.CreatedAt)
            .IsRequired();

        builder.Property(user => user.IsEmailVerified)
            .IsRequired();

        builder.Property(user => user.EmailVerifiedAt);

        builder.HasIndex(user => user.Email)
            .IsUnique();
    }
}
