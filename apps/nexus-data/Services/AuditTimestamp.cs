namespace AdminApi.Services;

/// <summary>
/// 監査ログ（visit_logs）の時刻を、PostgreSQL の timestamptz が保持できる精度にそろえます。
/// </summary>
/// <remarks>
/// .NET の <see cref="DateTimeOffset"/> は 100 ナノ秒単位（小数7桁）ですが、timestamptz はマイクロ秒
/// （小数6桁）までしか持たず、Npgsql は書き込み時に余りを切り捨てます。保存前の値で HMAC を計算すると、
/// 保存した値から計算し直したとき一致しなくなるため（docs/backup-restore.md §6）、保存する値と
/// ハッシュの入力の両方をここで切り捨てます。
/// </remarks>
public static class AuditTimestamp
{
    private const long TicksPerMicrosecond = TimeSpan.TicksPerMillisecond / 1000;

    /// <summary>マイクロ秒未満を切り捨てます（オフセットは保ちます）。すでに切り捨てた値には何もしません。</summary>
    public static DateTimeOffset TruncateToMicroseconds(DateTimeOffset value)
    {
        return value.AddTicks(-(value.UtcTicks % TicksPerMicrosecond));
    }
}
