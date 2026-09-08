using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportAiProcessingConfiguration : IEntityTypeConfiguration<SupportAiProcessing>
{
    public void Configure(EntityTypeBuilder<SupportAiProcessing> builder)
    {
        builder.ToTable("SupportAiProcessings");
        builder.HasKey(processing => processing.Id);

        builder.Property(processing => processing.Status)
            .HasConversion<string>()
            .HasMaxLength(24)
            .IsRequired();

        builder.Property(processing => processing.Provider).HasMaxLength(40).IsRequired();
        builder.Property(processing => processing.Model).HasMaxLength(100).IsRequired();
        builder.Property(processing => processing.FailureCode).HasMaxLength(80);

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_SupportAiProcessings_AttemptCount",
            "\"AttemptCount\" > 0"));

        builder.HasOne(processing => processing.Conversation)
            .WithMany(conversation => conversation.AiProcessings)
            .HasForeignKey(processing => processing.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(processing => processing.UserMessage)
            .WithMany()
            .HasForeignKey(processing => processing.UserMessageId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(processing => processing.AiMessage)
            .WithMany()
            .HasForeignKey(processing => processing.AiMessageId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(processing => processing.UserMessageId).IsUnique();
        builder.HasIndex(processing => new { processing.ConversationId, processing.Status });
        builder.HasIndex(processing => processing.LeaseExpiresAt);
    }
}
