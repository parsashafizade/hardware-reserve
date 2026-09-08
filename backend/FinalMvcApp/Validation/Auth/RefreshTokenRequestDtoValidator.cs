using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class RefreshTokenRequestDtoValidator : AbstractValidator<RefreshTokenRequestDto>
{
    public RefreshTokenRequestDtoValidator()
    {
        RuleFor(request => request.RefreshToken)
            .NotEmpty();
    }
}
