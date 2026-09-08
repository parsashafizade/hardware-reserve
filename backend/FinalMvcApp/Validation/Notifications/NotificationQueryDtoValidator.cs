using FinalMvcApp.DTOs.Notifications;
using FluentValidation;

namespace FinalMvcApp.Validation.Notifications;

public class NotificationQueryDtoValidator : AbstractValidator<NotificationQueryDto>
{
    public NotificationQueryDtoValidator()
    {
        RuleFor(request => request.PageSize)
            .InclusiveBetween(1, 50);

        RuleFor(request => request.Cursor)
            .MaximumLength(500);
    }
}
