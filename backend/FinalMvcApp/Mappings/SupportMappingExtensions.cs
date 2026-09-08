using AutoMapper;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Mappings;

public static class SupportMappingExtensions
{
    public static SupportConversationSummaryDto ToUserSummary(
        this IMapper mapper,
        SupportConversation conversation)
    {
        var dto = mapper.Map<SupportConversationSummaryDto>(conversation);
        dto.UnreadCount = conversation.ReadState.UserUnreadCount;
        dto.LastMessage = BuildLastMessage(conversation);
        return dto;
    }

    public static AdminSupportConversationDto ToAdminSummary(
        this IMapper mapper,
        SupportConversation conversation,
        int currentAdminUserId)
    {
        var dto = mapper.Map<AdminSupportConversationDto>(conversation);
        dto.UnreadCount = conversation.ReadState.AdminUnreadCount;
        dto.LastMessage = BuildLastMessage(conversation);
        dto.IsAssignedToCurrentAdmin = conversation.AssignedAdminUserId == currentAdminUserId;
        dto.Owner = conversation.UserId.HasValue
            ? new AdminSupportOwnerDto
            {
                OwnerType = "USER",
                UserId = conversation.UserId,
                FullName = conversation.User?.FullName,
                Email = conversation.User?.Email
            }
            : new AdminSupportOwnerDto
            {
                OwnerType = "ANONYMOUS"
            };
        return dto;
    }

    private static SupportLastMessageDto? BuildLastMessage(SupportConversation conversation)
    {
        if (!conversation.LastMessageAt.HasValue
            || !conversation.LastMessageSender.HasValue
            || conversation.LastMessageSequence <= 0)
        {
            return null;
        }

        return new SupportLastMessageDto
        {
            SequenceNumber = conversation.LastMessageSequence,
            SenderType = conversation.LastMessageSender.Value.ToString().ToUpperInvariant(),
            Preview = conversation.LastMessagePreview ?? string.Empty,
            SentAt = conversation.LastMessageAt.Value
        };
    }
}
