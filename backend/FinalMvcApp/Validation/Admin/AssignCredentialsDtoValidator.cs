using FinalMvcApp.DTOs.Admin;
using FluentValidation;

namespace FinalMvcApp.Validation.Admin;

public class AssignCredentialsDtoValidator : AbstractValidator<AssignCredentialsDto>
{
    public AssignCredentialsDtoValidator()
    {
        RuleFor(request => request.ReservationId)
            .GreaterThan(0);

        RuleFor(request => request.AssignedIp)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(request => request.AssignedUsername)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(request => request.AssignedPassword)
            .NotEmpty()
            .MaximumLength(100);
    }
}
