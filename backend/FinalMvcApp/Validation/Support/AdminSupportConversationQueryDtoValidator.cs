using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Models.Enums;
using FluentValidation;

namespace FinalMvcApp.Validation.Support;

public class AdminSupportConversationQueryDtoValidator : AbstractValidator<AdminSupportConversationQueryDto>
{
    public AdminSupportConversationQueryDtoValidator()
    {
        Include(new SupportConversationQueryDtoValidator());

        RuleFor(request => request.Status)
            .Must(status => status is null || Enum.TryParse<SupportConversationStatus>(status, true, out _))
            .WithMessage("Status is not a supported conversation status.");

        RuleFor(request => request.Category)
            .MaximumLength(80);
    }
}
