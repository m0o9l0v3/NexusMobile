import Foundation

struct ManualRouteOriginOption: Identifiable, Equatable, Sendable {
    let summary: SpotSummary
    let outdoorNodeID: String

    var id: CanonicalSpotID { summary.canonicalSpotID }
    var routeOrigin: RouteOrigin { .destination(id, approach: .fromOutdoor) }
}

struct ManualRouteOriginSnapshot: Equatable, Sendable {
    let destination: SpotSummary?
    let destinationSpotID: CanonicalSpotID
    let options: [ManualRouteOriginOption]
    let bundleVersion: Int64
    var savedMetadata: NexusSavedMetadata?
}

enum ManualRouteOriginLoadResult: Equatable, Sendable {
    case ready(ManualRouteOriginSnapshot)
    case empty(destination: SpotSummary?, destinationSpotID: CanonicalSpotID, bundleVersion: Int64,
               savedMetadata: NexusSavedMetadata?, message: NexusStateMessage)
    case destinationUnavailable(RouteRequestOutcome)
}
