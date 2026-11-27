import Foundation

enum ManualRouteOriginCatalog {
    static func load(in snapshot: PublishedBundleSnapshot, for destinationSpotID: CanonicalSpotID) -> ManualRouteOriginLoadResult {
        guard let map = snapshot.bundle.map?.geojson else {
            return .destinationUnavailable(.unavailable(RouteStateMessages.networkUnavailable))
        }
        let graph = RoutingGraph.build(from: map)
        guard !graph.nodes.isEmpty, !graph.adjacency.isEmpty else {
            return .destinationUnavailable(.unavailable(RouteStateMessages.networkUnavailable))
        }
        let catalog = BundleSpotCatalog(snapshot: snapshot)
        let destination = catalog.spot(for: destinationSpotID).map(catalog.summary(for:))
        let id = destinationSpotID.rawValue
        guard destination != nil || graph.destinations[id] != nil || graph.entrances[id] != nil else {
            return .destinationUnavailable(.unknownSpot(destinationSpotID))
        }
        let engine = RoutingEngine(graph: graph)
        if case .failure(let reason) = engine.resolveDestinationNode(for: id, approach: .fromOutdoor) {
            let name = destination?.displayName ?? map.features.first { $0.id == id }?.name
            return .destinationUnavailable(BundleRouteSolver.failure(reason, destinationSpotID: destinationSpotID, destinationName: name))
        }

        // 連結成分・通行方向は選択後に探索する。公開順を保ち、屋外に出発ノードのある地点だけを示す。
        let options: [ManualRouteOriginOption] = catalog.allSpots.compactMap { spot in
            guard case .success(let nodeID) = engine.resolveDestinationNode(for: spot.id, approach: .fromOutdoor),
                  graph.nodes[nodeID]?.location == .campus else { return nil }
            return ManualRouteOriginOption(summary: catalog.summary(for: spot), outdoorNodeID: nodeID)
        }
        let version = snapshot.bundle.meta.bundleVersion
        if options.isEmpty {
            return .empty(destination: destination, destinationSpotID: destinationSpotID, bundleVersion: version,
                          savedMetadata: catalog.savedMetadata, message: .init(title: "選べる出発地がありません",
                          detail: "屋外の歩行経路に接続する地点が公開されると選べます。", systemImageName: "figure.walk"))
        }
        return .ready(.init(destination: destination, destinationSpotID: destinationSpotID, options: options,
                            bundleVersion: version, savedMetadata: catalog.savedMetadata))
    }
}

struct ManualRouteOriginClient: Sendable {
    let isConfigured: Bool
    let provisionalNotice: String?
    var loadOptions: @Sendable (CanonicalSpotID) async throws -> ManualRouteOriginLoadResult
    var failureMessage = NexusStateMessage(title: "出発地を読み込めませんでした",
                                          detail: "もう一度読み込んでください。", systemImageName: "arrow.clockwise")

    static let unconfigured = ManualRouteOriginClient(isConfigured: false, provisionalNotice: nil, loadOptions: { _ in
        .destinationUnavailable(.unavailable(RouteStateMessages.dataUnavailable))
    })

    static func bundle(source: PublishedBundleSource, provisionalNotice: String? = nil) -> Self {
        Self(isConfigured: true, provisionalNotice: provisionalNotice) { id in
            do {
                if let snapshot = try await source.current() {
                    return ManualRouteOriginCatalog.load(in: snapshot, for: id)
                }
                return .destinationUnavailable(.unavailable(RouteStateMessages.dataUnavailable))
            } catch PublishedBundleSourceError.expired {
                throw PublishedBundleSourceError.expired
            } catch {
                return .destinationUnavailable(.unavailable(RouteStateMessages.dataUnavailable))
            }
        }
    }
}
