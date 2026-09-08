using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class RegisterRequestDtoValidator : AbstractValidator<RegisterRequestDto>
{
    public RegisterRequestDtoValidator()
    {
        RuleFor(request => request.FullName)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);

        RuleFor(request => request.Password)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(128);

        RuleFor(request => request.CaptchaId)
            .NotEmpty();

        RuleFor(request => request.CaptchaAnswer)
            .InclusiveBetween(0, 18);
    }
}
