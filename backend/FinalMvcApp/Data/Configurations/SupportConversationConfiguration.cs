using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportConversationConfiguration : IEntityTypeConfiguration<SupportConversation>
{
    public void Configure(EntityTypeBuilder<SupportConversation> builder)
    {
        builder.ToTable("SupportConversations");
        builder.HasKey(conversation => conversation.Id);

        builder.Property(conversation => conversation.Title)
            .IsRequired()
            .HasMaxLength(160);

        builder.Property(conversation => conversation.Category)
            .HasMaxLength(80);

        builder.Property(conversation => conversation.Status)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(conversation => conversation.CreatedAt).IsRequired();
        builder.Property(conversation => conversation.UpdatedAt).IsRequired();

        builder.Property(conversation => conversation.LastMessagePreview)
            .HasMaxLength(240);

        builder.Property(conversation => conversation.AiHandoffSummary)
            .HasMaxLength(2000);

        builder.Property(conversation => conversation.AiHandoffReason)
            .HasMaxLength(120);

        builder.Property(conversation => conversation.LastMessageSender)
            .HasConversion<string>()
            .HasMaxLength(16);

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_SupportConversations_ExactlyOneOwner",
                "(\"UserId\" IS NOT NULL AND \"AnonymousSessionId\" IS NULL) OR " +
                "(\"UserId\" IS NULL AND \"AnonymousSessionId\" IS NOT NULL)");
            table.HasCheckConstraint(
                "CK_SupportConversations_LastMessageSequence",
                "\"LastMessageSequence\" >= 0");
        });

        builder.HasOne(conversation => conversation.User)
            .WithMany(user => user.SupportConversations)
            .HasForeignKey(conversation => conversation.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(conversation => conversation.AnonymousSession)
            .WithMany(session => session.Conversations)
            .HasForeignKey(conversation => conversation.AnonymousSessionId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(conversation => conversation.AssignedAdminUser)
            .WithMany(user => user.AssignedSupportConversations)
            .HasForeignKey(conversation => conversation.AssignedAdminUserId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasIndex(conversation => new { conversation.UserId, conversation.UpdatedAt, conversation.Id });
        builder.HasIndex(conversation => new { conversation.AnonymousSessionId, conversation.UpdatedAt, conversation.Id });
        builder.HasIndex(conversation => new { conversation.Status, conversation.UpdatedAt, conversation.Id });
        builder.HasIndex(conversation => conversation.AssignedAdminUserId);
    }
}
