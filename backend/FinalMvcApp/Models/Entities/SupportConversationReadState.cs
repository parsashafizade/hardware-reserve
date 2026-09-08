namespace FinalMvcApp.Models.Entities;

public class SupportConversationReadState
{
    public Guid ConversationId { get; set; }

    public long UserLastReadSequence { get; set; }

    public long AdminLastReadSequence { get; set; }

    public int UserUnreadCount { get; set; }

    public int AdminUnreadCount { get; set; }

    public DateTime? UserReadAt { get; set; }

    public DateTime? AdminReadAt { get; set; }

    public SupportConversation Conversation { get; set; } = null!;
}
