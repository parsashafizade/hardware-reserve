using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class UpsertSupportQuickReplyRequestDtoValidator : AbstractValidator<UpsertSupportQuickReplyRequestDto>
{
    public UpsertSupportQuickReplyRequestDtoValidator()
    {
        RuleFor(request => request.Title)
            .NotEmpty()
            .Must(title => !string.IsNullOrWhiteSpace(title))
            .WithMessage("Title cannot contain only whitespace.")
            .MaximumLength(120);

        RuleFor(request => request.Content)
            .NotEmpty()
            .Must(content => !string.IsNullOrWhiteSpace(content))
            .WithMessage("Content cannot contain only whitespace.")
            .MaximumLength(2000);

        RuleFor(request => request.Category)
            .MaximumLength(80);

        RuleFor(request => request.SortOrder)
            .InclusiveBetween(0, 10000);
    }
}
