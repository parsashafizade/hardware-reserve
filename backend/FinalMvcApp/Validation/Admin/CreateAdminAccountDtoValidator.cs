using FinalMvcApp.DTOs.Admin;
using FluentValidation;

namespace FinalMvcApp.Validation.Admin;

public class CreateAdminAccountDtoValidator : AbstractValidator<CreateAdminAccountDto>
{
    public CreateAdminAccountDtoValidator()
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
    }
}
