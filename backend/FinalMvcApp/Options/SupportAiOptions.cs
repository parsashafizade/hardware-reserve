namespace FinalMvcApp.Options;

public class SupportAiOptions
{
    public const string SectionName = "SupportAI";

    public bool Enabled { get; set; }

    public string Provider { get; set; } = "Gemini";

    public int TimeoutSeconds { get; set; } = 20;

    public int MaxRetries { get; set; } = 1;

    public int MaxContextMessages { get; set; } = 24;

    public int MaxContextCharacters { get; set; } = 16000;

    public int MaxOutputTokens { get; set; } = 2048;

    public double MinimumConfidence { get; set; } = 0.65;

    public int ProcessingLeaseSeconds { get; set; } = 95;

    public int MinimumProcessingLeaseSeconds =>
        checked((2 * (MaxRetries + 1) * TimeoutSeconds) + 15);
}
