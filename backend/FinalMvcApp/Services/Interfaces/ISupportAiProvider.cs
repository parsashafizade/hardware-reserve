using FinalMvcApp.Services.AI;

namespace FinalMvcApp.Services.Interfaces;

public interface ISupportAiProvider
{
    string ProviderName { get; }

    string ModelName { get; }

    Task<SupportAiProviderDecision> GenerateAsync(
        SupportAiProviderRequest request,
        CancellationToken cancellationToken = default);
}
