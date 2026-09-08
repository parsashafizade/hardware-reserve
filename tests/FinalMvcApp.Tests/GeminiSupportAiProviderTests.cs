using FinalMvcApp.Options;
using FinalMvcApp.Services.AI;
using FinalMvcApp.Services.Implementations;
using Microsoft.Extensions.Options;
using System.Net;
using System.Text;
using System.Text.Json;

namespace FinalMvcApp.Tests;

public class GeminiSupportAiProviderTests
{
    [Fact]
    public async Task GenerateAsync_UsesHeaderSecretAndCurrentStructuredOutputContract()
    {
        var handler = new RecordingHttpHandler(_ => SuccessResponse());
        var provider = CreateProvider(handler, maxRetries: 0);

        var decision = await provider.GenerateAsync(Request());

        Assert.Equal(SupportAiIntent.PRICING, decision.Intent);
        Assert.Equal("The hourly price is shown on the server.", decision.Reply);
        Assert.Single(handler.Requests);
        var recorded = handler.Requests[0];
        Assert.Equal("test-api-key", recorded.ApiKey);
        Assert.DoesNotContain("test-api-key", recorded.Uri.ToString());
        Assert.DoesNotContain("test-api-key", recorded.Body);
        using var document = JsonDocument.Parse(recorded.Body);
        var generationConfig = document.RootElement.GetProperty("generationConfig");
        Assert.Equal(
            "application/json",
            generationConfig.GetProperty("responseFormat").GetProperty("text").GetProperty("mimeType").GetString());
        Assert.Equal(
            "object",
            generationConfig.GetProperty("responseFormat").GetProperty("text").GetProperty("schema").GetProperty("type").GetString());
    }

    [Fact]
    public async Task GenerateAsync_RetriesOneTransientRateLimit()
    {
        var call = 0;
        var handler = new RecordingHttpHandler(_ =>
        {
            call++;
            return call == 1
                ? new HttpResponseMessage(HttpStatusCode.TooManyRequests)
                : SuccessResponse();
        });
        var provider = CreateProvider(handler, maxRetries: 1);

        var decision = await provider.GenerateAsync(Request());

        Assert.Equal(SupportAiIntent.PRICING, decision.Intent);
        Assert.Equal(2, handler.Requests.Count);
    }

    [Fact]
    public async Task GenerateAsync_ClassifiesMissingCandidatesAsMalformedProviderResponse()
    {
        var handler = new RecordingHttpHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("{\"candidates\":[]}", Encoding.UTF8, "application/json")
        });
        var provider = CreateProvider(handler, maxRetries: 0);

        var exception = await Assert.ThrowsAsync<SupportAiProviderException>(() => provider.GenerateAsync(Request()));

        Assert.Equal("GEMINI_MALFORMED_RESPONSE", exception.FailureCode);
        Assert.Equal(1, exception.AttemptCount);
    }

    private static GeminiSupportAiProvider CreateProvider(HttpMessageHandler handler, int maxRetries)
    {
        var client = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/")
        };
        return new GeminiSupportAiProvider(
            client,
            Microsoft.Extensions.Options.Options.Create(new GeminiOptions
            {
                ApiKey = "test-api-key",
                Model = "gemini-3.6-flash"
            }),
            Microsoft.Extensions.Options.Options.Create(new SupportAiOptions
            {
                TimeoutSeconds = 5,
                MaxRetries = maxRetries,
                MaxOutputTokens = 1024
            }));
    }

    private static SupportAiProviderRequest Request()
    {
        return new SupportAiProviderRequest
        {
            Mode = SupportAiRequestMode.UserResponse,
            IsAuthenticated = false,
            LatestUserMessage = "How is hourly pricing shown?",
            ApprovedKnowledge = "Hourly prices appear in the server catalog.",
            Conversation =
            [
                new SupportAiChatMessage(
                    "USER",
                    "How is hourly pricing shown?",
                    DateTime.UtcNow,
                    1)
            ]
        };
    }

    private static HttpResponseMessage SuccessResponse()
    {
        var decision = JsonSerializer.Serialize(new
        {
            intent = "PRICING",
            action = "ANSWER",
            accountCapability = "NONE",
            reservationId = (int?)null,
            confidence = 0.98,
            reply = "The hourly price is shown on the server.",
            suggestedTitle = "Hourly server pricing",
            handoffSummary = ""
        });
        var response = JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new
                {
                    content = new
                    {
                        parts = new[] { new { text = decision } }
                    }
                }
            }
        });
        return new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(response, Encoding.UTF8, "application/json")
        };
    }
}

internal sealed class RecordingHttpHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _responseFactory;

    public RecordingHttpHandler(Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
    {
        _responseFactory = responseFactory;
    }

    public List<RecordedGeminiRequest> Requests { get; } = new();

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var body = request.Content is null
            ? string.Empty
            : await request.Content.ReadAsStringAsync(cancellationToken);
        Requests.Add(new RecordedGeminiRequest(
            request.RequestUri ?? throw new InvalidOperationException("Request URI is required."),
            request.Headers.GetValues("x-goog-api-key").Single(),
            body));
        return _responseFactory(request);
    }
}

internal sealed record RecordedGeminiRequest(Uri Uri, string ApiKey, string Body);
