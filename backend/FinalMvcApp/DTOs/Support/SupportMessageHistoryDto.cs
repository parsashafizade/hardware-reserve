using FinalMvcApp.DTOs.Common;

namespace FinalMvcApp.DTOs.Support;

public class SupportMessageHistoryDto
{
    public SupportConversationSummaryDto Conversation { get; set; } = new();

    public CursorPageDto<SupportMessageDto> Messages { get; set; } = new();
}
