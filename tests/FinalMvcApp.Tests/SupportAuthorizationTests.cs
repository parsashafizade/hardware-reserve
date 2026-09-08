using FinalMvcApp.Controllers;
using FinalMvcApp.DTOs.Support;
using FinalMvcApp.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http.Metadata;
using FinalMvcApp.Options;

namespace FinalMvcApp.Tests;

public class SupportAuthorizationTests
{
    [Fact]
    public void SupportHubAndAdminController_DeclareRequiredAuthorizationBoundaries()
    {
        var hubAuthorization = Assert.Single(
            typeof(SupportHub).GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
                .Cast<AuthorizeAttribute>());
        Assert.Null(hubAuthorization.Roles);

        var adminAuthorization = Assert.Single(
            typeof(AdminSupportController).GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
                .Cast<AuthorizeAttribute>());
        Assert.Equal("Admin", adminAuthorization.Roles);
    }

    [Theory]
    [InlineData(typeof(SupportController), "SendMessage")]
    [InlineData(typeof(AnonymousSupportController), "SendMessage")]
    [InlineData(typeof(AdminSupportController), "SendMessage")]
    [InlineData(typeof(AdminSupportController), "GenerateSuggestedReply")]
    public void ExpensiveSupportActions_UseMessageRateLimitAndBoundRequestBodies(
        Type controllerType,
        string actionName)
    {
        var action = controllerType.GetMethods().Single(method => method.Name == actionName);
        var rateLimit = Assert.Single(
            action.GetCustomAttributes(typeof(EnableRateLimitingAttribute), inherit: true)
                .Cast<EnableRateLimitingAttribute>());
        Assert.Equal(SupportRateLimitPolicies.Message, rateLimit.PolicyName);

        var requestLimit = Assert.Single(
            controllerType.GetCustomAttributes(typeof(RequestSizeLimitAttribute), inherit: true)
                .Cast<RequestSizeLimitAttribute>());
        Assert.Equal(32 * 1024, ((IRequestSizeLimitMetadata)requestLimit).MaxRequestBodySize);
    }

    [Fact]
    public async Task SignalRSubscriptionAccess_AllowsOwnerAndAdminButRejectsOtherUser()
    {
        await using var dbContext = TestDbFactory.Create();
        var owner = await SupportTestFactory.AddUserAsync(dbContext, "hub-owner@test.local");
        var otherUser = await SupportTestFactory.AddUserAsync(dbContext, "hub-other@test.local");
        var admin = await SupportTestFactory.AddUserAsync(
            dbContext,
            "hub-admin@test.local",
            FinalMvcApp.Models.Enums.UserRole.Admin);
        var service = SupportTestFactory.CreateSupportService(dbContext);
        var conversation = await service.CreateForUserAsync(owner.Id, new CreateSupportConversationRequestDto());

        Assert.True(await service.CanSubscribeAsync(owner.Id, false, conversation.Id));
        Assert.False(await service.CanSubscribeAsync(otherUser.Id, false, conversation.Id));
        Assert.True(await service.CanSubscribeAsync(admin.Id, true, conversation.Id));
    }
}
