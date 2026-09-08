using FinalMvcApp.DTOs.Servers;
using FluentValidation;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Validation.Servers;

public class CreateServerDtoValidator : AbstractValidator<CreateServerDto>
{
    public CreateServerDtoValidator()
    {
        RuleFor(server => server.CPU)
            .NotEmpty()
            .MaximumLength(120);

        RuleFor(server => server.GPU)
            .NotEmpty()
            .MaximumLength(120);

        RuleFor(server => server.RAM)
            .NotEmpty()
            .MaximumLength(40);

        RuleFor(server => server.Storage)
            .NotEmpty()
            .MaximumLength(40);

        RuleFor(server => server.OS)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(server => server.PricePerHour)
            .GreaterThan(0);

        RuleFor(server => server.PricePerDay)
            .GreaterThan(server => server.PricePerHour)
            .WithMessage("PricePerDay must be greater than PricePerHour.")
            .LessThanOrEqualTo(server => server.PricePerHour * 24)
            .WithMessage("PricePerDay cannot exceed 24 times PricePerHour.");

        RuleFor(server => server.OperationalStatus)
            .Must(value => Enum.TryParse<ServerOperationalStatus>(value, true, out var parsed) && Enum.IsDefined(parsed));

        RuleFor(server => server.PerformanceTier)
            .Must(value => Enum.TryParse<ServerPerformanceTier>(value, true, out var parsed) && Enum.IsDefined(parsed));

        RuleFor(server => server.CpuCapabilityLevel).InclusiveBetween(0, 100);
        RuleFor(server => server.GpuCapabilityLevel).InclusiveBetween(0, 100);

        RuleForEach(server => server.WorkloadCapabilities).ChildRules(capability =>
        {
            capability.RuleFor(item => item.WorkloadType)
                .Must(value => Enum.TryParse<ServerWorkloadType>(value, true, out var parsed) && Enum.IsDefined(parsed));
            capability.RuleFor(item => item.SuitabilityLevel).InclusiveBetween(1, 5);
        });

        RuleFor(server => server.WorkloadCapabilities)
            .NotNull()
            .Must(items => items is not null
                && items.Select(item => item.WorkloadType).Distinct(StringComparer.OrdinalIgnoreCase).Count() == items.Count)
            .WithMessage("Workload capabilities must be unique.");
    }
}
