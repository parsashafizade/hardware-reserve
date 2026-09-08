using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class ForgotPasswordRequestDtoValidator : AbstractValidator<ForgotPasswordRequestDto>
{
    public ForgotPasswordRequestDtoValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);
    }
}
