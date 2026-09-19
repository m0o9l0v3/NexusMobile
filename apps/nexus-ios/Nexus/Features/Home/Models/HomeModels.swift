import Foundation

/// Public navigation identifier. The value is intentionally kept verbatim:
/// canonical identifiers are case-sensitive and must never be derived from a display name.
struct CanonicalSpotID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct HomeEvent: Identifiable, Equatable, Sendable {
    let id: String
    let canonicalSpotID: CanonicalSpotID
    let category: String
    let title: String
    let timeText: String
    let timeContextText: String?
    let locationName: String
    let systemImageName: String
}

struct HomeAnnouncement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let elapsedText: String?
    let canonicalSpotID: CanonicalSpotID?
}

struct HomeSnapshot: Equatable, Sendable {
    let nextEvent: HomeEvent?
    let announcements: [HomeAnnouncement]
    /// Optional unread/summary badge count. The backend meaning is intentionally
    /// left open until the Home data contract is approved.
    let announcementBadgeCount: Int?
    let featuredEvents: [HomeEvent]

    init(
        nextEvent: HomeEvent?,
        announcements: [HomeAnnouncement],
        announcementBadgeCount: Int? = nil,
        featuredEvents: [HomeEvent]
    ) {
        self.nextEvent = nextEvent
        self.announcements = announcements
        self.announcementBadgeCount = announcementBadgeCount
        self.featuredEvents = featuredEvents
    }
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
    case empty(HomeStateMessage)
    case saved(HomeSnapshot, SavedHomeMetadata)
}

enum HomeViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(HomeSnapshot)
    case empty(HomeStateMessage)
    case failed(HomeStateMessage)
    case saved(HomeSnapshot, SavedHomeMetadata)
}
