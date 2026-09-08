namespace FinalMvcApp.Hubs;

public static class SupportHubGroups
{
    public const string Admins = "support:admins";

    public static string User(int userId) => $"support:user:{userId}";

    public static string Conversation(Guid conversationId) => $"support:conversation:{conversationId:N}";
}
