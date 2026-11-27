import Foundation

struct RoutePreviewTarget: Equatable, Sendable {
    let id: CanonicalSpotID
    let displayName: String
    let locationText: String

    init(id: CanonicalSpotID, displayName: String, locationText: String = "") {
        self.id = id
        self.displayName = displayName
        self.locationText = locationText
    }

    init(summary: SpotSummary) {
        self.init(id: summary.canonicalSpotID, displayName: summary.displayName, locationText: summary.locationText)
    }
}

struct RoutePreview: Equatable, Sendable {
    var outcome: RouteRequestOutcome
    var target: RoutePreviewTarget? = nil
    var buildings: [CampusMapContent.Building] = []
    var savedMetadata: NexusSavedMetadata? = nil
    var bundleVersion: Int64? = nil

    static let expired = Self(outcome: .unavailable(PublishedBundleSourceError.expiredMessage))

    var destination: RouteDestination? {
        guard case .accepted(let destination) = outcome,
              let route = destination.resolvedRoute,
              route.origin.coordinate != nil, route.destination.coordinate != nil,
              !route.segments.isEmpty else { return nil }
        return destination
    }

    var statusMessage: NexusStateMessage {
        if case .accepted = outcome {
            return .init(title: "経路を表示できません", detail: "経路の地図データを利用できません。",
                         systemImageName: "map")
        }
        return outcome.statusMessage
    }
}
