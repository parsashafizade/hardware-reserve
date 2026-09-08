using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class SupportMessage
{
    public Guid Id { get; set; }

    public Guid ConversationId { get; set; }

    public long SequenceNumber { get; set; }

    [Required]
    public SupportParticipantType SenderType { get; set; }

    public int? SenderUserId { get; set; }

    [Required]
    [StringLength(4000)]
    public string Content { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string ClientMessageId { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public SupportConversation Conversation { get; set; } = null!;

    public User? SenderUser { get; set; }

    public ICollection<SupportMessageAttachment> Attachments { get; set; } = new List<SupportMessageAttachment>();
}
