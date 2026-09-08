using FinalMvcApp.Models.Enums;
using System.ComponentModel.DataAnnotations;

namespace FinalMvcApp.Models.Entities;

public class SupportAiProcessing
{
    public Guid Id { get; set; }

    public Guid ConversationId { get; set; }

    public Guid UserMessageId { get; set; }

    public Guid? AiMessageId { get; set; }

    [Required]
    public SupportAiProcessingStatus Status { get; set; }

    public int AttemptCount { get; set; }

    [Required]
    [StringLength(40)]
    public string Provider { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string Model { get; set; } = string.Empty;

    [StringLength(80)]
    public string? FailureCode { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime StartedAt { get; set; }

    public DateTime LeaseExpiresAt { get; set; }

    public DateTime? CompletedAt { get; set; }

    public SupportConversation Conversation { get; set; } = null!;

    public SupportMessage UserMessage { get; set; } = null!;

    public SupportMessage? AiMessage { get; set; }
}
