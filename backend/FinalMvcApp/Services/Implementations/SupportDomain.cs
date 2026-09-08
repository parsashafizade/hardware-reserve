using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FluentValidation;
using FluentValidation.Results;

namespace FinalMvcApp.Services.Implementations;

internal static class SupportDomain
{
    public static SupportMessage CreateMessage(
        SupportConversation conversation,
        SupportParticipantType senderType,
        int? senderUserId,
        string clientMessageId,
        string content,
        DateTime now)
    {
        return new SupportMessage
        {
            Id = Guid.NewGuid(),
            ConversationId = conversation.Id,
            SequenceNumber = conversation.LastMessageSequence + 1,
            SenderType = senderType,
            SenderUserId = senderUserId,
            ClientMessageId = clientMessageId,
            Content = content,
            CreatedAt = now
        };
    }

    public static void ApplyMessageMetadata(SupportConversation conversation, SupportMessage message)
    {
        conversation.LastMessageSequence = message.SequenceNumber;
        conversation.LastMessageAt = message.CreatedAt;
        conversation.LastMessageSender = message.SenderType;
        conversation.LastMessagePreview = BuildPreview(message.Content);
        conversation.UpdatedAt = message.CreatedAt;
    }

    public static SupportConversationEvent CreateEvent(
        Guid conversationId,
        SupportAuditEventType eventType,
        SupportAuditActorType actorType,
        int? actorUserId,
        SupportConversationStatus? previousStatus,
        SupportConversationStatus? newStatus,
        DateTime occurredAt,
        string? details = null)
    {
        return new SupportConversationEvent
        {
            Id = Guid.NewGuid(),
            ConversationId = conversationId,
            EventType = eventType,
            ActorType = actorType,
            ActorUserId = actorUserId,
            PreviousStatus = previousStatus,
            NewStatus = newStatus,
            OccurredAt = occurredAt,
            Details = details
        };
    }

    public static string NormalizeMessageContent(string content)
    {
        var normalized = content.Replace("\0", string.Empty, StringComparison.Ordinal).Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new ValidationException(new[]
            {
                new ValidationFailure("Content", "Content cannot be empty.")
            });
        }

        return normalized;
    }

    public static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static string BuildPreview(string content)
    {
        var preview = string.Join(' ', content.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        return preview.Length <= 240 ? preview : preview[..240];
    }
}
