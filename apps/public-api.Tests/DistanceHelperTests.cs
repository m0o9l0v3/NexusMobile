using PublicApi.Helpers;
using Xunit;

namespace PublicApi.Tests;

public sealed class DistanceHelperTests
{
    [Fact]
    public void CalculateMeters_ReturnsZero_WhenPointsAreSame()
    {
        var distance = DistanceHelper.CalculateMeters(35.681236, 139.767125, 35.681236, 139.767125);

        Assert.Equal(0d, distance, 6);
    }

    [Fact]
    public void CalculateMeters_ReturnsExpectedRange_ForKnownPoints()
    {
        var tokyoStationLat = 35.681236;
        var tokyoStationLng = 139.767125;
        var shinjukuStationLat = 35.689592;
        var shinjukuStationLng = 139.700413;

        var distance = DistanceHelper.CalculateMeters(tokyoStationLat, tokyoStationLng, shinjukuStationLat, shinjukuStationLng);

        Assert.InRange(distance, 5800d, 6800d);
    }
}

