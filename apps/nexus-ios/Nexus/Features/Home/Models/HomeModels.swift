import Foundation

/// Public navigation identifier. The value is intentionally kept verbatim:
/// canonical identifiers are case-sensitive and must never be derived from a display name.
struct CanonicalSpotID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Home に出す開催枠1つ。1つのイベントが複数の枠を持つため、`id` は枠の ID、`eventID` はイベントの ID。
struct HomeEvent: Identifiable, Equatable, Sendable {
    let id: String
    let eventID: String
    let canonicalSpotID: CanonicalSpotID
    let category: String
    let title: String
    let timeText: String
    let timeContextText: String?
    let locationName: String
    let systemImageName: String
    /// 枠または開催日が中止か（E2-5 改訂1 EV-O1：一覧には中止と分かる形で残す）。
    let isCancelled: Bool
    let cancelNote: String?

    init(
        id: String,
        eventID: String? = nil,
        canonicalSpotID: CanonicalSpotID,
        category: String,
        title: String,
        timeText: String,
        timeContextText: String?,
        locationName: String,
        systemImageName: String,
        isCancelled: Bool = false,
        cancelNote: String? = nil
    ) {
        self.id = id
        self.eventID = eventID ?? id
        self.canonicalSpotID = canonicalSpotID
        self.category = category
        self.title = title
        self.timeText = timeText
        self.timeContextText = timeContextText
        self.locationName = locationName
        self.systemImageName = systemImageName
        self.isCancelled = isCancelled
        self.cancelNote = cancelNote
    }
}

/// Home の内容。お知らせは v1.0 では出さない（E2-5 改訂1 EV-D2）。
struct HomeSnapshot: Equatable, Sendable {
    /// 開催日カード（Home v1.0 下書き A）。開催日が0件なら nil で、カードごと出さない。
    let dayOverview: HomeDayOverview?
    /// 中止でない、これから参加できる最も早い枠。
    let nextEvent: HomeEvent?
    /// これから参加できる枠を開始の早い順に（EV-D3）。中止の枠も中止と分かる形で含む（EV-O1）。
    /// 開催日があって枠が残っていないときは空（最後の開催日の公開が終わった後など）。
    let upcomingEvents: [HomeEvent]

    init(dayOverview: HomeDayOverview? = nil, nextEvent: HomeEvent?, upcomingEvents: [HomeEvent]) {
        self.dayOverview = dayOverview
        self.nextEvent = nextEvent
        self.upcomingEvents = upcomingEvents
    }
}

/// 開催日カードの状態（Home v1.0 下書き §2 A、Figma `2790:1744`）。
enum HomeDayStatus: Equatable, Sendable {
    /// その日より前、または当日の `public_start` より前。
    case upcoming
    /// 当日で `public_start`〜`public_end` の間。
    case open
    /// 当日で `public_end` を過ぎた後、またはその日より後。
    case ended
    /// 当日だが公開時間が未設定で、開催前・開催中・終了を決められない（Figma 未作成）。
    case today
    /// `status == "cancelled"`。ほかの条件より優先する。
    case cancelled
}

/// Home の開催日カード1枚（`occurrences[].days[]` の1日）。日時は JST。
struct HomeDayOverview: Equatable, Sendable {
    let dayID: String
    /// 開催回の名前（`occurrences[].name`）。読み上げにだけ使う。
    let occurrenceName: String
    /// 「8月1日（日）10:00〜15:00」。公開時間が未設定なら日付だけ。
    let dateText: String
    let status: HomeDayStatus
    /// 「15:00まで公開中です」「開催まであと3日」など。中止は「この日の開催は中止になりました」。
    let detailText: String?
    /// 中止の理由（`cancel_note`）。
    let cancelNote: String?
    /// 同じ開催回のほかの開催日（配列の順）。
    let otherDays: [HomeOtherDay]
}

struct HomeOtherDay: Identifiable, Equatable, Sendable {
    let id: String
    let dateText: String
    let isCancelled: Bool
}

/// Home の「案内」に出すショートカット1つ（Home v1.0 下書き B）。記事がある分だけ作る。
struct HomeGuidanceShortcut: Identifiable, Equatable, Sendable {
    let shortcut: GuidanceHomeShortcut
    let articleID: GuidanceArticleID

    var id: GuidanceHomeShortcut { shortcut }
}

struct HomeStateMessage: Equatable, Sendable {
    let title: String
    let detail: String?
    let systemImageName: String
}

struct SavedHomeMetadata: Equatable, Sendable {
    let title: String
    let detail: String?
}

enum HomeFetchResult: Equatable, Sendable {
    case fresh(HomeSnapshot)
    /// 0件。保存版から作った0件なら `saved` を持ち、最新を確認できていないことを示す。
    case empty(HomeStateMessage, saved: SavedHomeMetadata? = nil)
    case saved(HomeSnapshot, SavedHomeMetadata)
}

enum HomeViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(HomeSnapshot)
    case empty(HomeStateMessage, saved: SavedHomeMetadata? = nil)
    case failed(HomeStateMessage)
    case saved(HomeSnapshot, SavedHomeMetadata)
}
