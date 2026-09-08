using FinalMvcApp.DTOs.Profile;
using FluentValidation;

namespace FinalMvcApp.Validation.Profile;

public class VerifyEmailChangeCodeRequestDtoValidator
    : AbstractValidator<VerifyEmailChangeCodeRequestDto>
{
    public VerifyEmailChangeCodeRequestDtoValidator()
    {
        RuleFor(request => request.Code)
            .NotEmpty()
            .Matches("^[0-9]{6}$")
            .WithMessage("Code must contain exactly 6 digits.");
    }
}
