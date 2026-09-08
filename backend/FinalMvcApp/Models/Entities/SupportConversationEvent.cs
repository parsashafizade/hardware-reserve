using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class SupportConversationEvent
{
    public Guid Id { get; set; }

    public Guid ConversationId { get; set; }

    [Required]
    public SupportAuditEventType EventType { get; set; }

    [Required]
    public SupportAuditActorType ActorType { get; set; }

    public int? ActorUserId { get; set; }

    public SupportConversationStatus? PreviousStatus { get; set; }

    public SupportConversationStatus? NewStatus { get; set; }

    [StringLength(1000)]
    public string? Details { get; set; }

    public DateTime OccurredAt { get; set; }

    public SupportConversation Conversation { get; set; } = null!;

    public User? ActorUser { get; set; }
}
