namespace PublicApi.Helpers;

public static class DistanceHelper
{
    private const double EarthRadiusMeters = 6371000d;

    public static double CalculateMeters(double lat1, double lng1, double lat2, double lng2)
    {
        var lat1Rad = DegreesToRadians(lat1);
        var lat2Rad = DegreesToRadians(lat2);
        var deltaLat = DegreesToRadians(lat2 - lat1);
        var deltaLng = DegreesToRadians(lng2 - lng1);

        var sinLat = Math.Sin(deltaLat / 2d);
        var sinLng = Math.Sin(deltaLng / 2d);
        var a = sinLat * sinLat + Math.Cos(lat1Rad) * Math.Cos(lat2Rad) * sinLng * sinLng;
        var c = 2d * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1d - a));

        return EarthRadiusMeters * c;
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180d;
}

