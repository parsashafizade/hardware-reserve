using FinalMvcApp.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FinalMvcApp.Data.Configurations;

public class SupportConversationReadStateConfiguration : IEntityTypeConfiguration<SupportConversationReadState>
{
    public void Configure(EntityTypeBuilder<SupportConversationReadState> builder)
    {
        builder.ToTable("SupportConversationReadStates");
        builder.HasKey(readState => readState.ConversationId);

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_SupportReadStates_Sequences",
                "\"UserLastReadSequence\" >= 0 AND \"AdminLastReadSequence\" >= 0");
            table.HasCheckConstraint(
                "CK_SupportReadStates_UnreadCounts",
                "\"UserUnreadCount\" >= 0 AND \"AdminUnreadCount\" >= 0");
        });

        builder.HasOne(readState => readState.Conversation)
            .WithOne(conversation => conversation.ReadState)
            .HasForeignKey<SupportConversationReadState>(readState => readState.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
