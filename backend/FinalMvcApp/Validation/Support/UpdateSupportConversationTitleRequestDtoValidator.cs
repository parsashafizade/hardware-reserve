using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class UpdateSupportConversationTitleRequestDtoValidator : AbstractValidator<UpdateSupportConversationTitleRequestDto>
{
    public UpdateSupportConversationTitleRequestDtoValidator()
    {
        RuleFor(request => request.Title)
            .NotEmpty()
            .Must(title => !string.IsNullOrWhiteSpace(title))
            .WithMessage("Title cannot contain only whitespace.")
            .MaximumLength(160);
    }
}
