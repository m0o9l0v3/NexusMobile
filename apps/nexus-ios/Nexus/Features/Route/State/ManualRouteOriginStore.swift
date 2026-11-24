import Foundation

@MainActor
@Observable
final class ManualRouteOriginStore {
    struct Session: Identifiable, Equatable {
        let id: UUID
        let destinationSpotID: CanonicalSpotID
        let requestedFrom: AppTab
        let currentOriginSpotID: CanonicalSpotID?
        var state: LoadState
    }

    enum LoadState: Equatable {
        case loading
        case loaded(ManualRouteOriginSnapshot)
        case empty(destination: SpotSummary?, destinationSpotID: CanonicalSpotID, bundleVersion: Int64,
                   savedMetadata: NexusSavedMetadata?, message: NexusStateMessage)
        case failed(NexusStateMessage)
    }

    private let client: ManualRouteOriginClient
    private let routeStore: RouteRequestStore
    private var sessionRevision = 0
    private(set) var session: Session?
    var isConfigured: Bool { client.isConfigured }
    var isPresenting: Bool { session != nil }
    var provisionalNotice: String? { client.provisionalNotice }

    init(client: ManualRouteOriginClient, routeStore: RouteRequestStore) {
        self.client = client
        self.routeStore = routeStore
    }

    func beginSelection(for destinationSpotID: CanonicalSpotID, from tab: AppTab, currentOriginSpotID: CanonicalSpotID? = nil) async {
        guard client.isConfigured else {
            await routeStore.requestRoute(to: destinationSpotID, from: tab)
            return
        }
        session = Session(id: UUID(), destinationSpotID: destinationSpotID, requestedFrom: tab,
                          currentOriginSpotID: currentOriginSpotID, state: .loading)
        await retryLoad()
    }

    func retryLoad() async {
        guard let current = session else { return }
        sessionRevision += 1
        let revision = sessionRevision
        session?.state = .loading
        do {
            let result = try await client.loadOptions(current.destinationSpotID)
            guard sessionRevision == revision else { return }
            switch result {
            case .ready(let snapshot):
                session?.state = .loaded(snapshot)
            case let .empty(destination, id, version, metadata, message):
                session?.state = .empty(destination: destination, destinationSpotID: id, bundleVersion: version,
                                        savedMetadata: metadata, message: message)
            case .destinationUnavailable:
                session = nil
                await routeStore.requestRoute(to: current.destinationSpotID, from: current.requestedFrom)
            }
        } catch {
            guard sessionRevision == revision else { return }
            session?.state = .failed(client.failureMessage)
        }
    }

    private var currentOrigin: CanonicalSpotID? {
        routeStore.activeRoute.map { CanonicalSpotID(rawValue: $0.origin.id) }
    }

    func beginOriginChangeForActiveRoute() async {
        guard let destination = routeStore.activeDestination else { return }
        await beginSelection(for: destination.canonicalSpotID, from: destination.requestedFrom, currentOriginSpotID: currentOrigin)
    }

    func beginOriginRetryForLastAttempt() async {
        guard let destination = routeStore.lastAttemptedDestination else { return }
        let currentOriginSpotID = destination == routeStore.activeDestination?.canonicalSpotID ? currentOrigin : nil
        await beginSelection(for: destination, from: routeStore.lastAttemptedTab ?? .map, currentOriginSpotID: currentOriginSpotID)
    }

    func selectOrigin(_ option: ManualRouteOriginOption) async {
        guard let current = session, case .loaded(let snapshot) = current.state,
              snapshot.options.contains(option) else { return }
        cancelSelection()
        await routeStore.requestRoute(from: option.routeOrigin, to: current.destinationSpotID, from: current.requestedFrom)
    }

    func cancelSelection() {
        sessionRevision += 1
        session = nil
    }
}
