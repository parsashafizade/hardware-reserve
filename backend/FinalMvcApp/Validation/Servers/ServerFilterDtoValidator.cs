using FinalMvcApp.DTOs.Servers;
using FluentValidation;

namespace FinalMvcApp.Validation.Servers;

public class ServerFilterDtoValidator : AbstractValidator<ServerFilterDto>
{
    public ServerFilterDtoValidator()
    {
        RuleFor(filter => filter.CPU)
            .MaximumLength(120)
            .When(filter => !string.IsNullOrWhiteSpace(filter.CPU));

        RuleFor(filter => filter.GPU)
            .MaximumLength(120)
            .When(filter => !string.IsNullOrWhiteSpace(filter.GPU));

        RuleFor(filter => filter.RAM)
            .MaximumLength(40)
            .When(filter => !string.IsNullOrWhiteSpace(filter.RAM));

        RuleFor(filter => filter.Storage)
            .MaximumLength(40)
            .When(filter => !string.IsNullOrWhiteSpace(filter.Storage));

        RuleFor(filter => filter.OS)
            .MaximumLength(100)
            .When(filter => !string.IsNullOrWhiteSpace(filter.OS));
    }
}
