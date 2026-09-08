using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class LoginRequestDtoValidator : AbstractValidator<LoginRequestDto>
{
    public LoginRequestDtoValidator()
    {
        RuleFor(request => request.Identifier)
            .NotEmpty()
            .MaximumLength(320);

        RuleFor(request => request.Password)
            .NotEmpty()
            .MaximumLength(128);

        RuleFor(request => request.CaptchaId)
            .NotEmpty();

        RuleFor(request => request.CaptchaAnswer)
            .InclusiveBetween(0, 18);
    }
}
