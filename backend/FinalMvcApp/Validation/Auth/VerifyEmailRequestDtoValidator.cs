using FinalMvcApp.DTOs.Auth;
using FluentValidation;

namespace FinalMvcApp.Validation.Auth;

public class VerifyEmailRequestDtoValidator : AbstractValidator<VerifyEmailRequestDto>
{
    public VerifyEmailRequestDtoValidator()
    {
        RuleFor(request => request.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);

        RuleFor(request => request.Code)
            .NotEmpty()
            .Matches(@"^\d{6}$");
    }
}
