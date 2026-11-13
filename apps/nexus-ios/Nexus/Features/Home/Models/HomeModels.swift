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
    /// 中止でない、これから参加できる最も早い枠。
    let nextEvent: HomeEvent?
    /// これから参加できる枠を開始の早い順に（EV-D3）。中止の枠も中止と分かる形で含む（EV-O1）。
    let upcomingEvents: [HomeEvent]
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
