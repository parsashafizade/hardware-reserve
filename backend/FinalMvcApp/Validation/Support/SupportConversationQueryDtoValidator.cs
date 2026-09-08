using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class SupportConversationQueryDtoValidator : AbstractValidator<SupportConversationQueryDto>
{
    public SupportConversationQueryDtoValidator()
    {
        RuleFor(request => request.PageSize)
            .InclusiveBetween(1, 50);

        RuleFor(request => request.Cursor)
            .MaximumLength(500);
    }
}
