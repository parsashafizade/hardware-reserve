using FinalMvcApp.Models.Entities;

namespace FinalMvcApp.Services.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) GenerateAccessToken(User user);
}
