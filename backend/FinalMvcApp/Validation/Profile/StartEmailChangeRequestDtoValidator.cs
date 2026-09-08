using FinalMvcApp.DTOs.Profile;
using FluentValidation;

namespace FinalMvcApp.Validation.Profile;

public class StartEmailChangeRequestDtoValidator
    : AbstractValidator<StartEmailChangeRequestDto>
{
    public StartEmailChangeRequestDtoValidator()
    {
        RuleFor(request => request.NewEmail)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(320);
    }
}
