using FinalMvcApp.DTOs.Profile;
using FluentValidation;

namespace FinalMvcApp.Validation.Profile;

public class UpdateProfileRequestDtoValidator
    : AbstractValidator<UpdateProfileRequestDto>
{
    public UpdateProfileRequestDtoValidator()
    {
        RuleFor(request => request.FullName)
            .NotEmpty()
            .MaximumLength(200);
    }
}