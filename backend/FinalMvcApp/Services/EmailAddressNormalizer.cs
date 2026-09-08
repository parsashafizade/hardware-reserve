namespace FinalMvcApp.Services;

public static class EmailAddressNormalizer
{
    public static string Normalize(string email)
    {
        return email.Trim().ToLowerInvariant();
    }
}
