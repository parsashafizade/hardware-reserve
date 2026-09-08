using System.Security.Claims;

namespace FinalMvcApp.Extensions;

public static class ClaimsPrincipalExtensions
{
    public static int GetUserId(this ClaimsPrincipal user)
    {
        var userId = user.FindFirstValue(ClaimTypes.NameIdentifier);

        if (!int.TryParse(userId, out var parsedUserId))
        {
            throw new UnauthorizedAccessException("The user identity is invalid.");
        }

        return parsedUserId;
    }
}
