using FinalMvcApp.DTOs.Support;

namespace FinalMvcApp.Services.Interfaces;

public interface ISupportAiOrchestrator
{
    Task<SupportAutomationResultDto> ProcessUserMessageAsync(
        Guid conversationId,
        Guid userMessageId,
        int? authenticatedUserId,
        CancellationToken cancellationToken = default);

    Task<SupportSuggestedReplyDto> GenerateAdminSuggestedReplyAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default);
}
