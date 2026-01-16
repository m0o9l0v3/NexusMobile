namespace AdminApi.Options;

public sealed class OneTimeCodeOptions
{
    public const string SectionName = "OneTimeCode";

    public string HashKey { get; init; } = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET";
    public int CodeBytesLength { get; init; } = 32;
}
