using FinalMvcApp.Data;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Implementations;
using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Implementations;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace FinalMvcApp.Tests;

internal sealed class SupportAiTestHarness
{
    private SupportAiTestHarness(
        SupportService supportService,
        SupportAiOrchestrator orchestrator,
        RecordingSupportNotifier notifier)
    {
        SupportService = supportService;
        Orchestrator = orchestrator;
        Notifier = notifier;
    }

    public SupportService SupportService { get; }

    public SupportAiOrchestrator Orchestrator { get; }

    public RecordingSupportNotifier Notifier { get; }

    public static SupportAiTestHarness Create(
        ApplicationDbContext dbContext,
        ISupportAiProvider provider,
        TimeProvider? timeProvider = null)
    {
        var mapper = SupportTestFactory.CreateMapper();
        var notifier = new RecordingSupportNotifier();
        var supportRepository = new SupportRepository(dbContext);
        var options = Microsoft.Extensions.Options.Options.Create(new SupportAiOptions
        {
            Enabled = true,
            MinimumConfidence = 0.65,
            MaxContextMessages = 24,
            MaxContextCharacters = 16000,
            ProcessingLeaseSeconds = 95
        });
        var clock = timeProvider ?? TimeProvider.System;
        var orchestrator = new SupportAiOrchestrator(
            supportRepository,
            provider,
            new SupportKnowledgeSource(),
            new SupportAccountContextService(
                new ReservationRepository(dbContext),
                new ServerRepository(dbContext)),
            new SupportAiPolicyService(options, clock),
            notifier,
            mapper,
            options,
            clock,
            NullLogger<SupportAiOrchestrator>.Instance);
        var supportService = new SupportService(
            supportRepository,
            notifier,
            orchestrator,
            mapper);

        return new SupportAiTestHarness(supportService, orchestrator, notifier);
    }
}

internal sealed class FakeSupportAiProvider : ISupportAiProvider
{
    private readonly Queue<Func<SupportAiProviderRequest, SupportAiProviderDecision>> _responses = new();
    private SupportAiProviderException? _failure;

    public string ProviderName => "Fake";

    public string ModelName => "fake-support-model";

    public List<SupportAiProviderRequest> Requests { get; } = new();

    public FakeSupportAiProvider Enqueue(SupportAiProviderDecision decision)
    {
        _responses.Enqueue(_ => decision);
        return this;
    }

    public FakeSupportAiProvider Enqueue(
        Func<SupportAiProviderRequest, SupportAiProviderDecision> response)
    {
        _responses.Enqueue(response);
        return this;
    }

    public FakeSupportAiProvider Fail(string failureCode, int attemptCount = 2)
    {
        _failure = new SupportAiProviderException(failureCode, attemptCount);
        return this;
    }

    public Task<SupportAiProviderDecision> GenerateAsync(
        SupportAiProviderRequest request,
        CancellationToken cancellationToken = default)
    {
        _ = cancellationToken;
        Requests.Add(request);

        if (_failure is not null)
        {
            throw _failure;
        }

        if (_responses.Count == 0)
        {
            throw new InvalidOperationException("No fake support AI response was configured.");
        }

        return Task.FromResult(_responses.Dequeue()(request));
    }
}

internal sealed class FixedTimeProvider : TimeProvider
{
    private readonly DateTimeOffset _utcNow;

    public FixedTimeProvider(DateTimeOffset utcNow)
    {
        _utcNow = utcNow;
    }

    public override DateTimeOffset GetUtcNow() => _utcNow;
}
