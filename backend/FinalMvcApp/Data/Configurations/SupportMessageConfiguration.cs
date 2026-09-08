using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportMessageConfiguration : IEntityTypeConfiguration<SupportMessage>
{
    public void Configure(EntityTypeBuilder<SupportMessage> builder)
    {
        builder.ToTable("SupportMessages");
        builder.HasKey(message => message.Id);

        builder.Property(message => message.SenderType)
            .HasConversion<string>()
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(message => message.Content)
            .IsRequired()
            .HasMaxLength(4000);

        builder.Property(message => message.ClientMessageId)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(message => message.CreatedAt).IsRequired();

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_SupportMessages_SequenceNumber",
            "\"SequenceNumber\" > 0"));

        builder.HasOne(message => message.Conversation)
            .WithMany(conversation => conversation.Messages)
            .HasForeignKey(message => message.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(message => message.SenderUser)
            .WithMany()
            .HasForeignKey(message => message.SenderUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(message => new { message.ConversationId, message.SequenceNumber }).IsUnique();
        builder.HasIndex(message => new { message.ConversationId, message.SenderType, message.ClientMessageId }).IsUnique();
    }
}
