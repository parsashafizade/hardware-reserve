using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class ResendVerificationCodeRequestDtoValidator
    : AbstractValidator<ResendVerificationCodeRequestDto>
{
    public ResendVerificationCodeRequestDtoValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);
    }
}
