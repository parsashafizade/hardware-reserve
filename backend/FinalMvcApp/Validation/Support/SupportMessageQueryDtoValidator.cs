using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class SupportMessageQueryDtoValidator : AbstractValidator<SupportMessageQueryDto>
{
    public SupportMessageQueryDtoValidator()
    {
        RuleFor(request => request.PageSize)
            .InclusiveBetween(1, 100);

        RuleFor(request => request.Cursor)
            .MaximumLength(500);
    }
}
