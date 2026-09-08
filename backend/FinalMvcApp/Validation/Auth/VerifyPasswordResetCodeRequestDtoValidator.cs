using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class VerifyPasswordResetCodeRequestDtoValidator
    : AbstractValidator<VerifyPasswordResetCodeRequestDto>
{
    public VerifyPasswordResetCodeRequestDtoValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);

        RuleFor(request => request.Code)
            .NotEmpty()
            .Matches(@"^\d{6}$")
            .WithMessage("Code must contain exactly 6 digits.");
    }
}