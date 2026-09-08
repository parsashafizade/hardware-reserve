using System.Globalization;
using System.Text;

namespace FinalMvcApp.Utils;

public static class SupportCursorCodec
{
    public static string EncodeConversation(DateTime updatedAt, Guid id)
    {
        var value = $"{updatedAt.ToUniversalTime().Ticks.ToString(CultureInfo.InvariantCulture)}:{id:N}";
        return Encode(value);
    }

    public static bool TryDecodeConversation(string? cursor, out DateTime? updatedAt, out Guid? id)
    {
        updatedAt = null;
        id = null;

        if (string.IsNullOrWhiteSpace(cursor))
        {
            return true;
        }

        if (!TryDecode(cursor, out var value))
        {
            return false;
        }

        var parts = value.Split(':', 2);
        if (parts.Length != 2
            || !long.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var ticks)
            || ticks < DateTime.MinValue.Ticks
            || ticks > DateTime.MaxValue.Ticks
            || !Guid.TryParseExact(parts[1], "N", out var parsedId))
        {
            return false;
        }

        updatedAt = new DateTime(ticks, DateTimeKind.Utc);
        id = parsedId;
        return true;
    }

    public static string EncodeSequence(long sequenceNumber)
    {
        return Encode(sequenceNumber.ToString(CultureInfo.InvariantCulture));
    }

    public static bool TryDecodeSequence(string? cursor, out long? sequenceNumber)
    {
        sequenceNumber = null;

        if (string.IsNullOrWhiteSpace(cursor))
        {
            return true;
        }

        if (!TryDecode(cursor, out var value)
            || !long.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var parsed)
            || parsed <= 0)
        {
            return false;
        }

        sequenceNumber = parsed;
        return true;
    }

    private static string Encode(string value)
    {
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static bool TryDecode(string value, out string decoded)
    {
        decoded = string.Empty;

        try
        {
            var base64 = value.Replace('-', '+').Replace('_', '/');
            base64 = base64.PadRight(base64.Length + ((4 - (base64.Length % 4)) % 4), '=');
            decoded = Encoding.UTF8.GetString(Convert.FromBase64String(base64));
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
