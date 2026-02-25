namespace PublicApi.Helpers;

public static class JstTimeHelper
{
    private static readonly TimeZoneInfo JstTimeZone = ResolveTimeZone();

    public static DateTimeOffset ToJst(DateTimeOffset value)
    {
        return TimeZoneInfo.ConvertTime(value, JstTimeZone);
    }

    public static DateOnly GetCurrentJstDate(DateTimeOffset utcNow)
    {
        var jst = ToJst(utcNow);
        return DateOnly.FromDateTime(jst.DateTime);
    }

    public static (DateTimeOffset StartUtc, DateTimeOffset EndUtc) GetUtcRangeForJstDay(DateOnly jstDate)
    {
        var startJst = new DateTimeOffset(jstDate.Year, jstDate.Month, jstDate.Day, 0, 0, 0, JstTimeZone.BaseUtcOffset);
        var endJst = startJst.AddDays(1);
        return (startJst.ToUniversalTime(), endJst.ToUniversalTime());
    }

    private static TimeZoneInfo ResolveTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Asia/Tokyo");
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Tokyo Standard Time");
        }
    }
}

