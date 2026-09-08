using FinalMvcApp.DTOs.Reservations;
using FluentValidation;

namespace FinalMvcApp.Validation.Reservations;

public class CreateReservationDtoValidator : AbstractValidator<CreateReservationDto>
{
    public CreateReservationDtoValidator()
    {
        RuleFor(reservation => reservation.ServerId)
            .GreaterThan(0);

        RuleFor(reservation => reservation.StartTime)
            .Must(startTime => startTime.ToUniversalTime() > DateTime.UtcNow)
            .WithMessage("StartTime must be in the future.");

        RuleFor(reservation => reservation.EndTime)
            .GreaterThan(reservation => reservation.StartTime)
            .WithMessage("EndTime must be later than StartTime.");

        RuleFor(reservation => reservation.QuotedTotalPrice)
            .GreaterThan(0)
            .When(reservation => reservation.QuotedTotalPrice.HasValue);
    }
}
