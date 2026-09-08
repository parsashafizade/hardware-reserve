using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class CreateSupportConversationRequestDtoValidator : AbstractValidator<CreateSupportConversationRequestDto>
{
    public CreateSupportConversationRequestDtoValidator()
    {
        RuleFor(request => request.Title)
            .Must(title => title is null || !string.IsNullOrWhiteSpace(title))
            .WithMessage("Title cannot contain only whitespace.")
            .MaximumLength(160);

        RuleFor(request => request.Category)
            .MaximumLength(80);
    }
}
