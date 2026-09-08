using FinalMvcApp.DTOs.Reservations;
using FluentValidation;

namespace FinalMvcApp.Validation.Reservations;

public class ReservationSuggestionRequestDtoValidator : AbstractValidator<ReservationSuggestionRequestDto>
{
    public ReservationSuggestionRequestDtoValidator()
    {
        RuleFor(request => request.ServerId)
            .GreaterThan(0);

        RuleFor(request => request.DesiredDurationHours)
            .GreaterThan(0)
            .LessThanOrEqualTo(24 * 30);
    }
}
