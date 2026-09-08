using AutoMapper;
using FinalMvcApp.DTOs.Auth;
using FinalMvcApp.DTOs.Profile;
using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.DTOs.Users;
using FinalMvcApp.Models.Entities;
using FinalMvcApp.Models.Enums;

namespace FinalMvcApp.Mappings;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<User, UserDto>();
        CreateMap<User, ProfileResponseDto>()
            .ForMember(destination => destination.Role, options => options.MapFrom(source => source.Role.ToString()));
        CreateMap<User, AuthenticatedUserDto>()
            .ForMember(destination => destination.Role, options => options.MapFrom(source => source.Role.ToString()));

        CreateMap<ServerWorkloadCapability, ServerWorkloadCapabilityDto>()
            .ForMember(destination => destination.WorkloadType, options => options.MapFrom(source => source.WorkloadType.ToString()));
        CreateMap<Server, ServerDto>()
            .ForMember(destination => destination.OperationalStatus, options => options.MapFrom(source => source.OperationalStatus.ToString()))
            .ForMember(destination => destination.PerformanceTier, options => options.MapFrom(source => source.PerformanceTier.ToString()));
        CreateMap<CreateServerDto, Server>()
            .ForMember(destination => destination.Id, options => options.Ignore())
            .ForMember(destination => destination.OperationalStatus, options => options.Ignore())
            .ForMember(destination => destination.PerformanceTier, options => options.Ignore())
            .ForMember(destination => destination.Reservations, options => options.Ignore())
            .ForMember(destination => destination.WorkloadCapabilities, options => options.Ignore())
            .ForMember(destination => destination.MaintenanceWindows, options => options.Ignore());

        CreateMap<SupportConversation, SupportConversationSummaryDto>()
            .ForMember(destination => destination.Status, options => options.MapFrom(source => source.Status.ToString()))
            .ForMember(destination => destination.IsAnonymous, options => options.MapFrom(source => source.AnonymousSessionId.HasValue))
            .ForMember(destination => destination.UnreadCount, options => options.Ignore())
            .ForMember(destination => destination.LastMessage, options => options.Ignore());

        CreateMap<SupportConversation, AdminSupportConversationDto>()
            .IncludeBase<SupportConversation, SupportConversationSummaryDto>()
            .ForMember(destination => destination.Owner, options => options.Ignore())
            .ForMember(destination => destination.IsAssigned, options => options.MapFrom(source => source.AssignedAdminUserId.HasValue))
            .ForMember(destination => destination.IsAssignedToCurrentAdmin, options => options.Ignore());

        CreateMap<SupportMessage, SupportMessageDto>()
            .ForMember(destination => destination.SenderType, options => options.MapFrom(source => source.SenderType.ToString().ToUpperInvariant()))
            .ForMember(destination => destination.SenderDisplayName, options => options.MapFrom(source =>
                source.SenderType == SupportParticipantType.Admin
                    ? "Support Team"
                    : source.SenderType == SupportParticipantType.AI
                        ? "HardwareReserve AI"
                        : "Customer"))
            .ForMember(destination => destination.ContentFormat, options => options.MapFrom(_ => "PLAIN_TEXT"));

        CreateMap<SupportQuickReply, SupportQuickReplyDto>();

        CreateMap<SupportConversationEvent, SupportConversationEventDto>()
            .ForMember(destination => destination.EventType, options => options.MapFrom(source => source.EventType.ToString()))
            .ForMember(destination => destination.ActorType, options => options.MapFrom(source => source.ActorType.ToString().ToUpperInvariant()))
            .ForMember(destination => destination.PreviousStatus, options => options.MapFrom(source =>
                source.PreviousStatus.HasValue ? source.PreviousStatus.Value.ToString() : null))
            .ForMember(destination => destination.NewStatus, options => options.MapFrom(source =>
                source.NewStatus.HasValue ? source.NewStatus.Value.ToString() : null));
    }
}
