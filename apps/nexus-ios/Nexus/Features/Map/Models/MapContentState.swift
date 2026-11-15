import Foundation

/// Map の地図そのもの（建物・ピン）の状態（#31）。地点詳細の状態（`MapSpotDetailState`）とは別に持つ。
///
/// 読込中・掲載なし・失敗を1つの表示にまとめない。特に、通信の失敗を「掲載なし」「0件」として見せない
/// （#31 工程3「通信失敗を0件にしない」）。
enum MapContentState: Equatable, Sendable {
    /// 地図の内容を読んでいる。
    case loading
    /// 描ける内容がある。
    case loaded(CampusMapContent)
    /// 読めたが描けるものが無い：まだ公開されていない（404）、または公開版に建物もピンも無い。
    case empty(NexusStateMessage)
    /// 読めなかった：通信・検証・保存の失敗、アプリの更新が必要など。再試行できる。
    case failed(NexusStateMessage)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// 再試行を出すか。失敗のときだけ。
    var allowsRetry: Bool {
        if case .failed = self { return true }
        return false
    }

    /// 画面に出す文言。読込中と地図があるときは nil。
    var message: NexusStateMessage? {
        switch self {
        case .loading, .loaded:
            return nil
        case .empty(let message), .failed(let message):
            return message
        }
    }

    /// 取得元から読んだ結果を状態に直す。
    ///
    /// - 版がある：描けるものがあれば `loaded`、なければ `empty`（公開版に地図が無い）。
    /// - 版が無い：理由が「未公開（404）」のときだけ `empty`。確認の失敗・理由不明は `failed`。
    /// - 読み出しで throw：`failed`。
    static func resolve(
        _ result: Result<PublishedBundleSnapshot?, Error>,
        absence: PublishedBundleAbsence
    ) -> MapContentState {
        switch result {
        case .failure:
            return .failed(MapContentStateMessage.loadFailed)
        case .success(let snapshot?):
            let content = CampusMapContent(bundle: snapshot.bundle)
            guard content.isDrawable else {
                return .empty(MapContentStateMessage.noMapInBundle)
            }
            return .loaded(content)
        case .success(nil):
            switch absence {
            case .notPublished:
                return .empty(MapContentStateMessage.notPublished)
            case .updateRequired:
                return .failed(MapContentStateMessage.updateRequired)
            case .checkFailed, .unknown:
                return .failed(MapContentStateMessage.loadFailed)
            }
        }
    }
}

extension CampusMapContent {
    /// 建物かピンが1つでもあるか。無ければ空の地図（世界地図）を構内地図のように見せない。
    var isDrawable: Bool {
        !buildings.isEmpty || !pins.isEmpty
    }
}

/// Map の地図の状態の文言（#31）。Figma #84 に該当する承認版が無いため、Home・探すの言い回しに揃えた仮の文言。
enum MapContentStateMessage {
    static let loadingTitle = "地図を読み込み中"

    /// 接続先が設定されていない（本番は構内の測量データが届くまでこの表示）。`UnavailableMapSurfaceView`。
    static let notProvided = NexusStateMessage(
        title: "構内地図は未提供です",
        detail: "地図データの接続後に、建物・階と地点を表示します。",
        systemImageName: "map"
    )

    static let notPublished = NexusStateMessage(
        title: "構内地図はまだ公開されていません",
        detail: "公開されると、建物・階と地点をここに表示します。",
        systemImageName: "map"
    )

    static let noMapInBundle = NexusStateMessage(
        title: "表示できる建物・地点がありません",
        detail: "公開中のデータに、地図に置ける建物と地点が含まれていません。",
        systemImageName: "map"
    )

    static let loadFailed = NexusStateMessage(
        title: "地図を読み込めませんでした",
        detail: "通信できる場所で再試行してください。掲載が無いわけではありません。",
        systemImageName: "wifi.exclamationmark"
    )

    static let updateRequired = NexusStateMessage(
        title: "アプリの更新が必要です",
        detail: "この地図データは今のアプリでは読めません。App Store で Nexus を更新してください。",
        systemImageName: "arrow.down.app"
    )
}
