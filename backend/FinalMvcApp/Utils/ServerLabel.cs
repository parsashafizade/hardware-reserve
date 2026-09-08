using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Utils;

public static class ServerLabel
{
    public static string For(Server server)
    {
        return string.IsNullOrWhiteSpace(server.GPU)
            || string.Equals(server.GPU.Trim(), "None", StringComparison.OrdinalIgnoreCase)
                ? server.CPU
                : server.GPU;
    }
}
