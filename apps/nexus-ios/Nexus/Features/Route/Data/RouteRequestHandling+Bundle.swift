import Foundation

enum RouteStateMessages {
    static let dataUnavailable = NexusStateMessage(title: "経路データを利用できません",
        detail: "公開データを取得できたあとに利用できます。", systemImageName: "map")
    static let networkUnavailable = NexusStateMessage(title: "歩行経路は未公開です",
        detail: "この地図で歩行ネットワークが公開されると利用できます。", systemImageName: "map")
    static let originRequired = NexusStateMessage(title: "出発地が設定されていません",
        detail: "経路を表示するには出発地が必要です。", systemImageName: "figure.walk")
}

enum BundleRouteSolver {
    static func resolve(in bundle: ParticipantBundle, origin: RouteOrigin?, destinationSpotID: CanonicalSpotID,
                        requestedFrom: AppTab, options: RoutingOptions = .init(), requestID: UUID = UUID()) -> RouteRequestOutcome {
        guard let map = bundle.map?.geojson else { return .unavailable(RouteStateMessages.networkUnavailable) }
        let graph = RoutingGraph.build(from: map)
        let id = destinationSpotID.rawValue
        let spotsByID = Dictionary(bundle.spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard spotsByID[id] != nil || graph.destinations[id] != nil || graph.entrances[id] != nil else {
            return .unknownSpot(destinationSpotID)
        }
        guard !graph.nodes.isEmpty, !graph.adjacency.isEmpty else {
            return .unavailable(RouteStateMessages.networkUnavailable)
        }

        let engine = RoutingEngine(graph: graph)
        let features = Dictionary(map.features.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func name(for id: String) -> String? { spotsByID[id]?.name ?? features[id]?.name }
        let destinationName = name(for: id)
        func failure(_ reason: RouteFailureReason) -> RouteRequestOutcome {
            switch reason {
            case .unknownDestination: .unknownSpot(destinationSpotID)
            case .unknownNode(let node): .routeFailure(.unknownOrigin(node))
            case .notRoutable(let reason):
                .routeFailure(.notRoutable(reason, destinationID: destinationSpotID, destinationName: destinationName))
            case .disconnected:
                .routeFailure(.disconnected(destinationID: destinationSpotID, destinationName: destinationName))
            case .unreachable:
                .routeFailure(.unreachable(destinationID: destinationSpotID, destinationName: destinationName))
            }
        }

        if case .failure(let reason) = engine.resolveDestinationNode(for: id, approach: .fromOutdoor) {
            return failure(reason)
        }
        guard let origin else { return .unavailable(RouteStateMessages.originRequired) }
        let originID: String
        let originName: String?
        let startNodeID: String
        switch origin {
        case let .destination(spot, approach):
            originID = spot.rawValue
            originName = name(for: originID)
            switch engine.resolveDestinationNode(for: originID, approach: approach) {
            case .success(let node): startNodeID = node
            case .failure(.notRoutable(let reason)): return .routeFailure(.originNotRoutable(reason))
            case .failure: return .routeFailure(.unknownOrigin(originID))
            }
        case let .node(node, displayName):
            originID = node
            originName = displayName
            startNodeID = node
        }

        switch engine.findRoute(from: startNodeID, toDestination: id, options: options) {
        case .failure(let reason):
            return failure(reason)
        case .samePoint(let path):
            return .samePoint(.init(destinationSpotID: destinationSpotID, displayName: destinationName,
                                    nodeID: path.destinationNodeID))
        case .found(let path):
            var coordinates: [String: CampusMapCoordinate] = [:]
            for nodeID in path.nodeIDs {
                coordinates[nodeID] = features[nodeID]?.point.flatMap(CampusMapCoordinate.init(geoJSONPosition:))
            }
            let labels = path.traversedFloorIDs.map { id in
                guard let floor = map.floors.first(where: { $0.id == id }) else { return id }
                return [name(for: floor.buildingID), floor.name ?? id].compactMap { $0 }.joined(separator: " ")
            }
            let landmarks = OutdoorRouteStepBuilder.landmarksByNodeID(in: bundle)
            let outdoorSteps = OutdoorRouteStepBuilder.buildSteps(from: path, originName: originName,
                destinationName: destinationName, landmarksByNodeID: landmarks)
            let route = ResolvedRoute(requestID: requestID,
                origin: .init(id: originID, displayName: originName, coordinate: coordinates[startNodeID]),
                destination: .init(id: id, displayName: destinationName, coordinate: coordinates[path.destinationNodeID]),
                path: path, segments: RoutePolylineBuilder.buildSegments(from: path, nodeCoordinates: coordinates),
                traversedFloorLabels: labels, bundleVersion: bundle.meta.bundleVersion, outdoorSteps: outdoorSteps)
            return .accepted(.init(canonicalSpotID: destinationSpotID, requestedFrom: requestedFrom, resolvedRoute: route))
        }
    }
}

extension RouteRequestHandling {
    static func bundle(source: PublishedBundleSource, defaultOrigin: RouteOrigin? = nil,
                       options: RoutingOptions = .init()) -> RouteRequestHandling {
        RouteRequestHandling { origin, destination, tab in
            guard let snapshot = try? await source.current() else {
                return .unavailable(RouteStateMessages.dataUnavailable)
            }
            return BundleRouteSolver.resolve(in: snapshot.bundle, origin: origin ?? defaultOrigin,
                                             destinationSpotID: destination, requestedFrom: tab, options: options)
        }
    }
}
