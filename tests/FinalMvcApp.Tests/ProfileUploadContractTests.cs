using FinalMvcApp.Controllers;
using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.AspNetCore.Mvc;

namespace FinalMvcApp.Tests;

public class ProfileUploadContractTests
{
    [Fact]
    public void UploadProfileImage_AllowsMultipartOverheadAboveFileLimit()
    {
        var method = typeof(MeController).GetMethod(
            nameof(MeController.UploadProfileImage));
        Assert.NotNull(method);
        var limit = Assert.Single(
            method.GetCustomAttributes(typeof(RequestSizeLimitAttribute), true)
                .Cast<RequestSizeLimitAttribute>());

        Assert.Equal(
            (2 * 1024 * 1024) + (64 * 1024),
            ((IRequestSizeLimitMetadata)limit).MaxRequestBodySize);
    }
}
