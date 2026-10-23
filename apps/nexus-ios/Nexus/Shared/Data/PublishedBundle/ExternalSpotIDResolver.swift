import Foundation

/// bundle の外から来た spot の ID の解決結果（E2-5 §6 規則11）。
enum ExternalSpotIDResolution: Equatable, Sendable {
    /// この版で公開中の spot の canonical ID。端末に保存するならこの値を保存する。
    case resolved(CanonicalSpotID)
    /// この版に掲載がない。別の地点へ置き換えない（E1-3、E2-5 §5.3 の5）。
    case notListed
}

/// bundle の外から来た spot の ID を、1つの版の中で解決する唯一の場所（E2-5 §6 規則11、O-3d U2）。
///
/// - 対象：イベントの会場 `SpotCode`、案内記事の関連地点、端末に保存した状態、将来のディープリンクなど、
///   bundle 以外のデータ源から来る ID。bundle 内の参照（spots・地図・タブ間の受け渡し）は通さない。
/// - 照合：`spots[].id` との完全一致 → `id_aliases[].alias` との完全一致で1段だけ → どちらも無い、
///   または解決先が `spots` に無ければ未掲載。大文字小文字を区別し、正規化しない。alias を連鎖させない。
/// - alias で解決したかどうかは返さない（利用者に表示しない）。入力 ID も結果もログに残さず、送信しない。
/// - 資料上の旧 ID（E1-7 の74件など）は台帳に登録しないため、ここでは未掲載になる（O-3a）。
struct ExternalSpotIDResolver: Sendable {
    private let spotIDs: Set<String>
    private let aliases: [String: String]

    init(bundle: ParticipantBundle) {
        spotIDs = Set(bundle.spots.map(\.id))
        // 不変条件（§5.3 の2）で alias の一意性は検査済み。重複していても最初の行だけを使い、推測で選ばない。
        aliases = Dictionary(
            bundle.idAliases.map { ($0.alias, $0.canonicalID) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func resolve(_ rawValue: String) -> ExternalSpotIDResolution {
        if spotIDs.contains(rawValue) {
            return .resolved(CanonicalSpotID(rawValue: rawValue))
        }
        // alias は1段だけ。解決先が spot でなければ（別の alias を指していても）未掲載とする。
        if let canonicalID = aliases[rawValue], spotIDs.contains(canonicalID) {
            return .resolved(CanonicalSpotID(rawValue: canonicalID))
        }
        return .notListed
    }

    func resolve(_ spotID: CanonicalSpotID) -> ExternalSpotIDResolution {
        resolve(spotID.rawValue)
    }
}
