using FinalMvcApp.DTOs.Common;

namespace FinalMvcApp.DTOs.Support;

public class AdminSupportMessageHistoryDto
{
    public AdminSupportConversationDto Conversation { get; set; } = new();

    public CursorPageDto<SupportMessageDto> Messages { get; set; } = new();
}
