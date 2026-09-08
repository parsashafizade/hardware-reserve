using FinalMvcApp.DTOs.Servers;
using FinalMvcApp.Validation.Servers;

namespace FinalMvcApp.Tests;

public class ServerPricingValidatorTests
{
    [Fact]
    public void CreateServer_WhenDailyRateIsDiscounted_IsValid()
    {
        var validator = new CreateServerDtoValidator();
        var request = CreateRequest(75_000m, 1_350_000m);

        var result = validator.Validate(request);

        Assert.True(result.IsValid);
    }

    [Theory]
    [InlineData(75_000, 75_000)]
    [InlineData(75_000, 1_800_001)]
    public void CreateServer_WhenDailyRateIsIncoherent_IsInvalid(
        long pricePerHour,
        long pricePerDay)
    {
        var validator = new CreateServerDtoValidator();
        var request = CreateRequest(pricePerHour, pricePerDay);

        var result = validator.Validate(request);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == nameof(CreateServerDto.PricePerDay));
    }

    private static CreateServerDto CreateRequest(decimal pricePerHour, decimal pricePerDay)
    {
        return new CreateServerDto
        {
            CPU = "AMD EPYC 7543",
            GPU = "NVIDIA RTX 3080 10GB",
            RAM = "64GB",
            Storage = "2TB NVMe",
            OS = "Ubuntu 24.04",
            PricePerHour = pricePerHour,
            PricePerDay = pricePerDay,
            IsActive = true
        };
    }
}
