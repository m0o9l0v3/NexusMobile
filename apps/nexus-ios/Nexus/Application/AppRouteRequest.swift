import Foundation

struct HomeSearchRequest: Equatable, Sendable {
    let query: String?
    let categoryID: String?

    static let empty = HomeSearchRequest(query: nil, categoryID: nil)
}

enum AppRouteRequest: Equatable, Sendable {
    case search(HomeSearchRequest)
    case allAnnouncements
    case announcementDetails(id: String, canonicalSpotID: CanonicalSpotID?)
    case allEvents
    case eventDetails(eventID: String, canonicalSpotID: CanonicalSpotID)
    case spotDetails(canonicalSpotID: CanonicalSpotID)
    case route(destinationSpotID: CanonicalSpotID)
}
