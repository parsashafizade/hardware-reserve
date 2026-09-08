using FinalMvcApp.DTOs.Dashboard;
using FluentValidation;

namespace FinalMvcApp.Validation.Dashboard;

public class CommandSearchQueryDtoValidator : AbstractValidator<CommandSearchQueryDto>
{
    public CommandSearchQueryDtoValidator()
    {
        RuleFor(request => request.Query)
            .NotEmpty()
            .MaximumLength(80);

        RuleFor(request => request.Limit)
            .InclusiveBetween(1, 8);
    }
}
