using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportConversationEventConfiguration : IEntityTypeConfiguration<SupportConversationEvent>
{
    public void Configure(EntityTypeBuilder<SupportConversationEvent> builder)
    {
        builder.ToTable("SupportConversationEvents");
        builder.HasKey(supportEvent => supportEvent.Id);

        builder.Property(supportEvent => supportEvent.EventType)
            .HasConversion<string>()
            .HasMaxLength(40)
            .IsRequired();

        builder.Property(supportEvent => supportEvent.ActorType)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(supportEvent => supportEvent.PreviousStatus)
            .HasConversion<string>()
            .HasMaxLength(32);

        builder.Property(supportEvent => supportEvent.NewStatus)
            .HasConversion<string>()
            .HasMaxLength(32);

        builder.Property(supportEvent => supportEvent.Details)
            .HasMaxLength(1000);

        builder.Property(supportEvent => supportEvent.OccurredAt).IsRequired();

        builder.HasOne(supportEvent => supportEvent.Conversation)
            .WithMany(conversation => conversation.Events)
            .HasForeignKey(supportEvent => supportEvent.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(supportEvent => supportEvent.ActorUser)
            .WithMany()
            .HasForeignKey(supportEvent => supportEvent.ActorUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(supportEvent => new { supportEvent.ConversationId, supportEvent.OccurredAt, supportEvent.Id });
        builder.HasIndex(supportEvent => supportEvent.EventType);
    }
}
