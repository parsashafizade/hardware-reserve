using FinalMvcApp.Services.AI;

namespace FinalMvcApp.Services.Interfaces;

public interface ISupportAiPolicyService
{
    SupportAiPolicyOutcome? EvaluateDeterministicMessage(string latestUserMessage);

    SupportAiPolicyOutcome Evaluate(
        SupportAiProviderDecision decision,
        SupportAccountContext? accountContext,
        string latestUserMessage,
        bool isAuthenticated);

    string BuildProviderFailureReply(string latestUserMessage);

    string BuildProviderFailureSummary(string failureCode, string latestUserMessage);
}
