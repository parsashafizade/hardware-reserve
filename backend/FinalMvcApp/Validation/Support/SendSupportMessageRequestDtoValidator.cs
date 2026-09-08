using FinalMvcApp.DTOs.Support;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class SendSupportMessageRequestDtoValidator : AbstractValidator<SendSupportMessageRequestDto>
{
    public SendSupportMessageRequestDtoValidator()
    {
        RuleFor(request => request.ClientMessageId)
            .NotEmpty()
            .MinimumLength(8)
            .MaximumLength(100);

        RuleFor(request => request.Content)
            .NotEmpty()
            .Must(content => !string.IsNullOrWhiteSpace(content))
            .WithMessage("Content cannot contain only whitespace.")
            .MaximumLength(4000);
    }
}
