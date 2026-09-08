using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Interfaces;

namespace FinalMvcApp.Services.Implementations;

public class DisabledSupportAiProvider : ISupportAiProvider
{
    public string ProviderName => "Disabled";

    public string ModelName => "none";

    public Task<SupportAiProviderDecision> GenerateAsync(
        SupportAiProviderRequest request,
        CancellationToken cancellationToken = default)
    {
        _ = request;
        _ = cancellationToken;
        throw new SupportAiProviderException("AI_DISABLED", 1);
    }
}
