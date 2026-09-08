using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class SupportConversation
{
    public Guid Id { get; set; }

    public int? UserId { get; set; }

    public Guid? AnonymousSessionId { get; set; }

    [Required]
    [StringLength(160)]
    public string Title { get; set; } = string.Empty;

    [StringLength(80)]
    public string? Category { get; set; }

    [Required]
    public SupportConversationStatus Status { get; set; } = SupportConversationStatus.AI_ACTIVE;

    public int? AssignedAdminUserId { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public DateTime? ResolvedAt { get; set; }

    public DateTime? ClosedAt { get; set; }

    [StringLength(2000)]
    public string? AiHandoffSummary { get; set; }

    [StringLength(120)]
    public string? AiHandoffReason { get; set; }

    public DateTime? AiHandoffGeneratedAt { get; set; }

    public long LastMessageSequence { get; set; }

    public DateTime? LastMessageAt { get; set; }

    [StringLength(240)]
    public string? LastMessagePreview { get; set; }

    public SupportParticipantType? LastMessageSender { get; set; }

    public User? User { get; set; }

    public AnonymousSupportSession? AnonymousSession { get; set; }

    public User? AssignedAdminUser { get; set; }

    public SupportConversationReadState ReadState { get; set; } = null!;

    public ICollection<SupportMessage> Messages { get; set; } = new List<SupportMessage>();

    public ICollection<SupportConversationEvent> Events { get; set; } = new List<SupportConversationEvent>();

    public ICollection<SupportAiProcessing> AiProcessings { get; set; } = new List<SupportAiProcessing>();

    public ICollection<UserNotification> Notifications { get; set; } = new List<UserNotification>();
}
