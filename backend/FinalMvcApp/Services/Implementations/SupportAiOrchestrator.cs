using AutoMapper;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;
using FinalMvcApp.Options;
using FinalMvcApp.Repositories.Interfaces;
using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Interfaces;
using Microsoft.Extensions.Options;

namespace FinalMvcApp.Services.Implementations;

public class SupportAiOrchestrator : ISupportAiOrchestrator
{
    private const string DefaultConversationTitle = "Support conversation";
    private readonly ISupportRepository _supportRepository;
    private readonly ISupportAiProvider _provider;
    private readonly ISupportKnowledgeSource _knowledgeSource;
    private readonly ISupportAccountContextService _accountContextService;
    private readonly ISupportAiPolicyService _policyService;
    private readonly ISupportRealtimeNotifier _realtimeNotifier;
    private readonly IMapper _mapper;
    private readonly SupportAiOptions _options;
    private readonly TimeProvider _timeProvider;
    private readonly ILogger<SupportAiOrchestrator> _logger;

    public SupportAiOrchestrator(
        ISupportRepository supportRepository,
        ISupportAiProvider provider,
        ISupportKnowledgeSource knowledgeSource,
        ISupportAccountContextService accountContextService,
        ISupportAiPolicyService policyService,
        ISupportRealtimeNotifier realtimeNotifier,
        IMapper mapper,
        IOptions<SupportAiOptions> options,
        TimeProvider timeProvider,
        ILogger<SupportAiOrchestrator> logger)
    {
        _supportRepository = supportRepository;
        _provider = provider;
        _knowledgeSource = knowledgeSource;
        _accountContextService = accountContextService;
        _policyService = policyService;
        _realtimeNotifier = realtimeNotifier;
        _mapper = mapper;
        _options = options.Value;
        _timeProvider = timeProvider;
        _logger = logger;
    }

    public async Task<SupportAutomationResultDto> ProcessUserMessageAsync(
        Guid conversationId,
        Guid userMessageId,
        int? authenticatedUserId,
        CancellationToken cancellationToken = default)
    {
        var acquisition = await AcquireAsync(
            conversationId,
            userMessageId,
            authenticatedUserId,
            cancellationToken);

        if (!acquisition.ShouldProcess)
        {
            return await BuildExistingResultAsync(acquisition, cancellationToken);
        }

        var history = await GetBoundedHistoryAsync(conversationId, cancellationToken);
        var initialDecision = default(SupportAiProviderDecision);

        try
        {
            var deterministicOutcome = _policyService.EvaluateDeterministicMessage(
                acquisition.UserMessage!.Content);
            if (deterministicOutcome is not null)
            {
                return await CompleteAsync(
                    acquisition,
                    deterministicOutcome,
                    SelectTitle(string.Empty, string.Empty, history),
                    null,
                    0,
                    cancellationToken);
            }

            initialDecision = await _provider.GenerateAsync(
                BuildProviderRequest(
                    SupportAiRequestMode.UserResponse,
                    authenticatedUserId.HasValue,
                    acquisition.UserMessage!.Content,
                    history,
                    null),
                cancellationToken);

            var finalDecision = initialDecision;
            SupportAccountContext? accountContext = null;
            if (!HasDeterministicPolicy(initialDecision.Intent))
            {
                accountContext = await LoadRequestedContextAsync(
                    authenticatedUserId,
                    initialDecision,
                    cancellationToken);

                if (accountContext is not null
                    && !accountContext.RequiresAuthentication
                    && !accountContext.RequestedReservationNotFound)
                {
                    var contextualDecision = await _provider.GenerateAsync(
                        BuildProviderRequest(
                            SupportAiRequestMode.ContextualResponse,
                            authenticatedUserId.HasValue,
                            acquisition.UserMessage.Content,
                            history,
                            accountContext),
                        cancellationToken);
                    finalDecision = MergeContextualDecision(initialDecision, contextualDecision);
                }
            }

            var outcome = _policyService.Evaluate(
                finalDecision,
                accountContext,
                acquisition.UserMessage.Content,
                authenticatedUserId.HasValue);
            var title = SelectTitle(
                finalDecision.SuggestedTitle,
                initialDecision.SuggestedTitle,
                history);

            return await CompleteAsync(
                acquisition,
                outcome,
                title,
                null,
                1,
                cancellationToken);
        }
        catch (SupportAiProviderException exception)
        {
            _logger.LogWarning(
                "Support AI provider failed for conversation {ConversationId}, message {MessageId}, code {FailureCode}.",
                conversationId,
                userMessageId,
                exception.FailureCode);

            var outcome = new SupportAiPolicyOutcome
            {
                Reply = _policyService.BuildProviderFailureReply(acquisition.UserMessage!.Content),
                Escalate = true,
                EscalationReason = "AI_PROVIDER_FAILURE",
                HandoffSummary = _policyService.BuildProviderFailureSummary(
                    exception.FailureCode,
                    acquisition.UserMessage.Content)
            };

            return await CompleteAsync(
                acquisition,
                outcome,
                SelectTitle(string.Empty, initialDecision?.SuggestedTitle ?? string.Empty, history),
                exception.FailureCode,
                exception.AttemptCount,
                cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            const string failureCode = "AI_ORCHESTRATION_FAILURE";
            _logger.LogWarning(
                "Support AI orchestration failed for conversation {ConversationId}, message {MessageId}, code {FailureCode}.",
                conversationId,
                userMessageId,
                failureCode);

            var outcome = new SupportAiPolicyOutcome
            {
                Reply = _policyService.BuildProviderFailureReply(acquisition.UserMessage!.Content),
                Escalate = true,
                EscalationReason = failureCode,
                HandoffSummary = _policyService.BuildProviderFailureSummary(
                    failureCode,
                    acquisition.UserMessage.Content)
            };

            return await CompleteAsync(
                acquisition,
                outcome,
                SelectTitle(string.Empty, initialDecision?.SuggestedTitle ?? string.Empty, history),
                failureCode,
                1,
                cancellationToken);
        }
    }

    public async Task<SupportSuggestedReplyDto> GenerateAdminSuggestedReplyAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        var conversation = await _supportRepository.GetConversationAsync(conversationId, cancellationToken)
            ?? throw new KeyNotFoundException("Support conversation not found.");

        if (conversation.Status == SupportConversationStatus.CLOSED)
        {
            throw new InvalidOperationException("Closed support conversations do not accept reply suggestions.");
        }

        var history = await GetBoundedHistoryAsync(conversationId, cancellationToken);
        var latestUserMessage = history.LastOrDefault(message => message.SenderType == "USER")?.Content
            ?? throw new InvalidOperationException("A user message is required before generating a reply suggestion.");

        try
        {
            var deterministicOutcome = _policyService.EvaluateDeterministicMessage(latestUserMessage);
            if (deterministicOutcome is not null)
            {
                return new SupportSuggestedReplyDto
                {
                    Draft = deterministicOutcome.Reply,
                    GeneratedAt = _timeProvider.GetUtcNow().UtcDateTime
                };
            }

            var analysis = await _provider.GenerateAsync(
                BuildProviderRequest(
                    SupportAiRequestMode.UserResponse,
                    conversation.UserId.HasValue,
                    latestUserMessage,
                    history,
                    null),
                cancellationToken);

            if (HasDeterministicPolicy(analysis.Intent))
            {
                var deterministic = _policyService.Evaluate(
                    analysis,
                    null,
                    latestUserMessage,
                    conversation.UserId.HasValue);
                return new SupportSuggestedReplyDto
                {
                    Draft = deterministic.Reply,
                    GeneratedAt = _timeProvider.GetUtcNow().UtcDateTime
                };
            }

            var accountContext = await LoadRequestedContextAsync(
                conversation.UserId,
                analysis,
                cancellationToken);
            var suggestion = await _provider.GenerateAsync(
                BuildProviderRequest(
                    SupportAiRequestMode.AdminSuggestedReply,
                    conversation.UserId.HasValue,
                    latestUserMessage,
                    history,
                    accountContext),
                cancellationToken);
            var outcome = _policyService.Evaluate(
                MergeContextualDecision(analysis, suggestion),
                accountContext,
                latestUserMessage,
                conversation.UserId.HasValue);

            return new SupportSuggestedReplyDto
            {
                Draft = outcome.Reply,
                GeneratedAt = _timeProvider.GetUtcNow().UtcDateTime
            };
        }
        catch (SupportAiProviderException exception)
        {
            _logger.LogWarning(
                "Admin support reply suggestion failed for conversation {ConversationId}, code {FailureCode}.",
                conversationId,
                exception.FailureCode);
            throw new InvalidOperationException("An automated reply suggestion is temporarily unavailable.");
        }
    }

    private async Task<ProcessingAcquisition> AcquireAsync(
        Guid conversationId,
        Guid userMessageId,
        int? authenticatedUserId,
        CancellationToken cancellationToken)
    {
        return await _supportRepository.ExecuteWithConversationLockAsync(
            conversationId,
            async (conversation, operationCancellationToken) =>
            {
                EnsureOwner(conversation, authenticatedUserId);
                var userMessage = await _supportRepository.GetMessageByIdAsync(
                    userMessageId,
                    operationCancellationToken);

                if (userMessage is null
                    || userMessage.ConversationId != conversation.Id
                    || userMessage.SenderType != SupportParticipantType.User)
                {
                    throw new KeyNotFoundException("Support user message not found.");
                }

                var existing = await _supportRepository.GetAiProcessingByUserMessageIdAsync(
                    userMessageId,
                    true,
                    operationCancellationToken);
                if (existing is not null)
                {
                    if (existing.Status is SupportAiProcessingStatus.Completed
                        or SupportAiProcessingStatus.Escalated
                        or SupportAiProcessingStatus.Superseded)
                    {
                        return new ProcessingAcquisition(false, false, userMessage, existing);
                    }

                    var now = _timeProvider.GetUtcNow().UtcDateTime;
                    if (existing.LeaseExpiresAt > now)
                    {
                        return new ProcessingAcquisition(false, true, userMessage, existing);
                    }

                    existing.AttemptCount++;
                    existing.StartedAt = now;
                    existing.LeaseExpiresAt = now.AddSeconds(_options.ProcessingLeaseSeconds);
                    existing.FailureCode = null;
                    return new ProcessingAcquisition(true, false, userMessage, existing);
                }

                if (conversation.Status != SupportConversationStatus.AI_ACTIVE)
                {
                    return new ProcessingAcquisition(false, false, userMessage, null);
                }

                var createdAt = _timeProvider.GetUtcNow().UtcDateTime;
                var processing = new SupportAiProcessing
                {
                    Id = Guid.NewGuid(),
                    ConversationId = conversation.Id,
                    UserMessageId = userMessage.Id,
                    Status = SupportAiProcessingStatus.Processing,
                    AttemptCount = 1,
                    Provider = _provider.ProviderName,
                    Model = _provider.ModelName,
                    CreatedAt = createdAt,
                    StartedAt = createdAt,
                    LeaseExpiresAt = createdAt.AddSeconds(_options.ProcessingLeaseSeconds)
                };
                await _supportRepository.AddAiProcessingAsync(processing, operationCancellationToken);
                return new ProcessingAcquisition(true, false, userMessage, processing);
            },
            cancellationToken);
    }

    private async Task<SupportAutomationResultDto> BuildExistingResultAsync(
        ProcessingAcquisition acquisition,
        CancellationToken cancellationToken)
    {
        if (acquisition.InProgress)
        {
            return new SupportAutomationResultDto { Status = "PROCESSING" };
        }

        if (acquisition.Processing?.Status == SupportAiProcessingStatus.Superseded)
        {
            return new SupportAutomationResultDto { Status = "SUPERSEDED" };
        }

        SupportMessageDto? assistantMessage = null;
        if (acquisition.Processing?.AiMessageId is Guid aiMessageId)
        {
            var message = await _supportRepository.GetMessageByIdAsync(aiMessageId, cancellationToken);
            assistantMessage = message is null ? null : _mapper.Map<SupportMessageDto>(message);
        }

        return new SupportAutomationResultDto
        {
            Status = acquisition.Processing?.Status == SupportAiProcessingStatus.Escalated
                ? "ESCALATED"
                : acquisition.Processing?.Status == SupportAiProcessingStatus.Completed
                    ? "COMPLETED"
                    : "SKIPPED",
            AssistantMessage = assistantMessage
        };
    }

    private async Task<SupportAutomationResultDto> CompleteAsync(
        ProcessingAcquisition acquisition,
        SupportAiPolicyOutcome outcome,
        string? title,
        string? failureCode,
        int providerAttempts,
        CancellationToken cancellationToken)
    {
        var result = await _supportRepository.ExecuteWithConversationLockAsync(
            acquisition.Processing!.ConversationId,
            async (conversation, operationCancellationToken) =>
            {
                var processing = await _supportRepository.GetAiProcessingByUserMessageIdAsync(
                    acquisition.UserMessage!.Id,
                    true,
                    operationCancellationToken)
                    ?? throw new InvalidOperationException("Support AI processing state was not found.");

                if (processing.Status is SupportAiProcessingStatus.Completed
                    or SupportAiProcessingStatus.Escalated
                    or SupportAiProcessingStatus.Superseded)
                {
                    return new CompletionResult(processing, null, false, false, false, conversation.UserId);
                }

                if (conversation.Status != SupportConversationStatus.AI_ACTIVE
                    || conversation.LastMessageSequence > acquisition.UserMessage.SequenceNumber)
                {
                    processing.Status = SupportAiProcessingStatus.Superseded;
                    processing.CompletedAt = _timeProvider.GetUtcNow().UtcDateTime;
                    return new CompletionResult(processing, null, false, false, false, conversation.UserId);
                }

                var now = _timeProvider.GetUtcNow().UtcDateTime;
                var aiMessage = SupportDomain.CreateMessage(
                    conversation,
                    SupportParticipantType.AI,
                    null,
                    $"ai:{acquisition.UserMessage.Id:N}",
                    SupportDomain.NormalizeMessageContent(outcome.Reply),
                    now);
                await _supportRepository.AddMessageAsync(aiMessage, operationCancellationToken);
                SupportDomain.ApplyMessageMetadata(conversation, aiMessage);
                conversation.ReadState.UserUnreadCount++;

                var titleChanged = false;
                if (conversation.Title == DefaultConversationTitle && !string.IsNullOrWhiteSpace(title))
                {
                    conversation.Title = title;
                    titleChanged = true;
                    await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                        conversation.Id,
                        SupportAuditEventType.AiTitleGenerated,
                        SupportAuditActorType.AI,
                        null,
                        conversation.Status,
                        conversation.Status,
                        now), operationCancellationToken);
                }

                var statusChanged = false;
                if (outcome.Escalate)
                {
                    var previousStatus = conversation.Status;
                    conversation.Status = SupportConversationStatus.WAITING_FOR_ADMIN;
                    conversation.AssignedAdminUserId = null;
                    conversation.AiHandoffReason = Truncate(outcome.EscalationReason, 120);
                    conversation.AiHandoffSummary = Truncate(outcome.HandoffSummary, 2000);
                    conversation.AiHandoffGeneratedAt = now;
                    processing.Status = SupportAiProcessingStatus.Escalated;
                    statusChanged = true;
                    await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                        conversation.Id,
                        SupportAuditEventType.AiEscalated,
                        SupportAuditActorType.AI,
                        null,
                        previousStatus,
                        conversation.Status,
                        now,
                        $"reason={conversation.AiHandoffReason}"), operationCancellationToken);
                }
                else
                {
                    processing.Status = SupportAiProcessingStatus.Completed;
                    conversation.ReadState.AdminLastReadSequence = aiMessage.SequenceNumber;
                    conversation.ReadState.AdminUnreadCount = 0;
                    conversation.ReadState.AdminReadAt = now;

                    if (outcome.Resolve)
                    {
                        var previousStatus = conversation.Status;
                        conversation.Status = SupportConversationStatus.RESOLVED;
                        conversation.ResolvedAt = now;
                        statusChanged = true;
                        await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                            conversation.Id,
                            SupportAuditEventType.AiResolved,
                            SupportAuditActorType.AI,
                            null,
                            previousStatus,
                            conversation.Status,
                            now), operationCancellationToken);
                    }
                }

                if (!string.IsNullOrWhiteSpace(failureCode))
                {
                    processing.FailureCode = Truncate(failureCode, 80);
                    processing.AttemptCount = Math.Max(processing.AttemptCount, providerAttempts);
                    await _supportRepository.AddEventAsync(SupportDomain.CreateEvent(
                        conversation.Id,
                        SupportAuditEventType.AiProcessingFailed,
                        SupportAuditActorType.System,
                        null,
                        SupportConversationStatus.AI_ACTIVE,
                        conversation.Status,
                        now,
                        $"provider={processing.Provider};model={processing.Model};code={processing.FailureCode};attempts={processing.AttemptCount}"), operationCancellationToken);
                }

                processing.AiMessageId = aiMessage.Id;
                processing.CompletedAt = now;
                return new CompletionResult(
                    processing,
                    aiMessage,
                    true,
                    statusChanged,
                    titleChanged,
                    conversation.UserId);
            },
            cancellationToken);

        if (result.CreatedMessage && result.Message is not null)
        {
            await _realtimeNotifier.PublishAsync(
                result.Processing.ConversationId,
                result.Message.Id,
                result.Message.SequenceNumber,
                "MESSAGE_CREATED",
                result.OwnerUserId,
                CancellationToken.None);
        }

        if (result.StatusChanged)
        {
            await _realtimeNotifier.PublishAsync(
                result.Processing.ConversationId,
                null,
                null,
                result.Processing.Status == SupportAiProcessingStatus.Escalated
                    ? "AI_HANDOFF_REQUESTED"
                    : "CONVERSATION_RESOLVED",
                result.OwnerUserId,
                CancellationToken.None);
        }

        if (result.TitleChanged)
        {
            await _realtimeNotifier.PublishAsync(
                result.Processing.ConversationId,
                null,
                null,
                "CONVERSATION_TITLE_CHANGED",
                result.OwnerUserId,
                CancellationToken.None);
        }

        return await BuildExistingResultAsync(
            new ProcessingAcquisition(false, false, acquisition.UserMessage, result.Processing),
            cancellationToken);
    }

    private async Task<SupportAccountContext?> LoadRequestedContextAsync(
        int? authenticatedUserId,
        SupportAiProviderDecision decision,
        CancellationToken cancellationToken)
    {
        if (decision.AccountCapability == SupportAccountCapability.NONE)
        {
            return null;
        }

        if (!SupportAiGuardrails.IsAccountCapabilityAllowed(
            decision.Intent,
            decision.AccountCapability))
        {
            return null;
        }

        return await _accountContextService.GetContextAsync(
            authenticatedUserId,
            decision.AccountCapability,
            decision.ReservationId,
            cancellationToken);
    }

    private SupportAiProviderRequest BuildProviderRequest(
        SupportAiRequestMode mode,
        bool authenticated,
        string latestUserMessage,
        IReadOnlyList<SupportAiChatMessage> history,
        SupportAccountContext? accountContext)
    {
        var safeLatestMessage = SupportAiGuardrails.RedactSensitiveData(latestUserMessage);
        var safeHistory = history
            .Select(message => message with
            {
                Content = SupportAiGuardrails.RedactSensitiveData(message.Content)
            })
            .ToList();

        return new SupportAiProviderRequest
        {
            Mode = mode,
            IsAuthenticated = authenticated,
            LatestUserMessage = safeLatestMessage,
            ApprovedKnowledge = _knowledgeSource.GetApprovedKnowledge(),
            Conversation = safeHistory,
            AccountContext = accountContext
        };
    }

    private async Task<IReadOnlyList<SupportAiChatMessage>> GetBoundedHistoryAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var messages = await _supportRepository.GetMessagesAsync(
            conversationId,
            null,
            _options.MaxContextMessages,
            cancellationToken);
        var selected = messages
            .OrderBy(message => message.SequenceNumber)
            .Select(message => new SupportAiChatMessage(
                message.SenderType.ToString().ToUpperInvariant(),
                message.Content,
                message.CreatedAt,
                message.SequenceNumber))
            .ToList();

        while (selected.Count > 1
            && selected.Sum(message => message.Content.Length) > _options.MaxContextCharacters)
        {
            selected.RemoveAt(0);
        }

        return selected;
    }

    private static void EnsureOwner(SupportConversation conversation, int? authenticatedUserId)
    {
        var validOwner = authenticatedUserId.HasValue
            ? conversation.UserId == authenticatedUserId.Value
            : !conversation.UserId.HasValue && conversation.AnonymousSessionId.HasValue;

        if (!validOwner)
        {
            throw new UnauthorizedAccessException("Support conversation access is not permitted.");
        }
    }

    private static bool HasDeterministicPolicy(SupportAiIntent intent)
    {
        return intent is SupportAiIntent.CANCELLATION
            or SupportAiIntent.REFUND
            or SupportAiIntent.HUMAN_REQUEST
            or SupportAiIntent.PAYMENT_DISPUTE
            or SupportAiIntent.MUTATION_REQUIRED
            or SupportAiIntent.OUT_OF_SCOPE
            or SupportAiIntent.UNKNOWN
            or SupportAiIntent.PROMPT_INJECTION;
    }

    private static SupportAiProviderDecision MergeContextualDecision(
        SupportAiProviderDecision initial,
        SupportAiProviderDecision contextual)
    {
        return new SupportAiProviderDecision
        {
            Intent = initial.Intent,
            Action = contextual.Action,
            AccountCapability = initial.AccountCapability,
            ReservationId = initial.ReservationId,
            Confidence = Math.Min(initial.Confidence, contextual.Confidence),
            Reply = contextual.Reply,
            SuggestedTitle = contextual.SuggestedTitle,
            HandoffSummary = contextual.HandoffSummary
        };
    }

    private static string? SelectTitle(
        string preferredTitle,
        string fallbackProviderTitle,
        IReadOnlyList<SupportAiChatMessage> history)
    {
        var candidate = SanitizeTitle(preferredTitle) ?? SanitizeTitle(fallbackProviderTitle);
        if (candidate is not null)
        {
            return candidate;
        }

        var firstMeaningful = history
            .Where(message => message.SenderType == "USER")
            .Select(message => SanitizeTitle(message.Content))
            .FirstOrDefault(title => title is not null);
        return firstMeaningful;
    }

    private static string? SanitizeTitle(string value)
    {
        var normalized = string.Join(' ', SupportAiGuardrails.RedactSensitiveData(value)
            .Replace("\0", string.Empty, StringComparison.Ordinal)
            .Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        var generic = normalized.Trim().ToLowerInvariant();
        if (generic is "hello" or "hi" or "support" or "question" or "سلام" or "پشتیبانی" or "سوال" or "سؤال")
        {
            return null;
        }

        return Truncate(normalized, 160);
    }

    private static string Truncate(string value, int maxLength)
    {
        return value.Length <= maxLength ? value : value[..maxLength];
    }

    private sealed record ProcessingAcquisition(
        bool ShouldProcess,
        bool InProgress,
        SupportMessage? UserMessage,
        SupportAiProcessing? Processing);

    private sealed record CompletionResult(
        SupportAiProcessing Processing,
        SupportMessage? Message,
        bool CreatedMessage,
        bool StatusChanged,
        bool TitleChanged,
        int? OwnerUserId);
}
