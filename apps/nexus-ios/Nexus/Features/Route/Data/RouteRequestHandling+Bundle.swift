import CoreLocation
import Foundation

enum RouteStateMessages {
    static let dataUnavailable = NexusStateMessage(title: "経路データを利用できません",
        detail: "公開データを取得できたあとに利用できます。", systemImageName: "map")
    static let networkUnavailable = NexusStateMessage(title: "歩行経路は未公開です",
        detail: "この地図で歩行ネットワークが公開されると利用できます。", systemImageName: "map")
    static let previewFailed = NexusStateMessage(title: "経路を読み込めませんでした",
        detail: "時間をおいて、もう一度「マップで見る」をお試しください。", systemImageName: "exclamationmark.circle")
    static let originRequired = NexusStateMessage(title: "出発地が設定されていません",
        detail: "経路を表示するには出発地が必要です。", systemImageName: "figure.walk")
}

enum BundleRouteSolver {
    static func resolve(in bundle: ParticipantBundle, origin: RouteOrigin?, destinationSpotID: CanonicalSpotID,
                        requestedFrom: AppTab, options: RoutingOptions = .init(), requestID: UUID = UUID(),
                        previewOrigin: ((RoutingGraph, MapGeoJSON) -> RouteOrigin?)? = nil,
                        savedMetadata: NexusSavedMetadata? = nil) -> RouteRequestOutcome {
        guard let map = bundle.map?.geojson else { return .unavailable(RouteStateMessages.networkUnavailable) }
        let graph = RoutingGraph.build(from: map)
        guard !graph.nodes.isEmpty, !graph.adjacency.isEmpty else {
            return .unavailable(RouteStateMessages.networkUnavailable)
        }
        let id = destinationSpotID.rawValue
        let spotsByID = Dictionary(bundle.spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard spotsByID[id] != nil || graph.destinations[id] != nil || graph.entrances[id] != nil else {
            return .unknownSpot(destinationSpotID)
        }

        let engine = RoutingEngine(graph: graph)
        let features = Dictionary(map.features.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func name(for id: String) -> String? { spotsByID[id]?.name ?? features[id]?.name }
        let destinationName = name(for: id)

        if case .failure(let reason) = engine.resolveDestinationNode(for: id, approach: .fromOutdoor) {
            return failure(reason, destinationSpotID: destinationSpotID, destinationName: destinationName)
        }
        guard let origin = previewOrigin?(graph, map) ?? origin else { return .unavailable(RouteStateMessages.originRequired) }
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
            return failure(reason, destinationSpotID: destinationSpotID, destinationName: destinationName)
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
            return .accepted(.init(canonicalSpotID: destinationSpotID, requestedFrom: requestedFrom, resolvedRoute: route,
                                   savedMetadata: savedMetadata))
        }
    }

    static func failure(_ reason: RouteFailureReason, destinationSpotID: CanonicalSpotID, destinationName: String?) -> RouteRequestOutcome {
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
}

extension RouteRequestHandling {
    static func bundle(source: PublishedBundleSource, defaultOrigin: RouteOrigin? = nil,
                       options: RoutingOptions = .init()) -> RouteRequestHandling {
        var handler = RouteRequestHandling { origin, destination, tab in
            guard let snapshot = try? await source.current() else {
                return .unavailable(RouteStateMessages.dataUnavailable)
            }
            return BundleRouteSolver.resolve(in: snapshot.bundle, origin: origin ?? defaultOrigin,
                                             destinationSpotID: destination, requestedFrom: tab, options: options,
                                             savedMetadata: BundleSpotCatalog(snapshot: snapshot).savedMetadata)
        }
        handler.loadPreview = { fix, manualOrigin, destination, tab in
            let snapshot: PublishedBundleSnapshot
            do {
                guard let current = try await source.current() else {
                    return RoutePreview(outcome: .unavailable(RouteStateMessages.dataUnavailable))
                }
                snapshot = current
            } catch {
                return RoutePreview(outcome: .unavailable(RouteStateMessages.previewFailed))
            }

            let catalog = BundleSpotCatalog(snapshot: snapshot)
            let summary = catalog.spot(for: destination).map(catalog.summary(for:))
            let saved = catalog.savedMetadata
            let outcome = BundleRouteSolver.resolve(
                in: snapshot.bundle, origin: defaultOrigin, destinationSpotID: destination, requestedFrom: tab,
                options: options, previewOrigin: { graph, map in
                    RoutePreviewOrigin.nearestNode(to: fix, in: graph, map: map)
                        ?? manualOrigin
                        ?? (defaultOrigin == nil ? RoutePreviewOrigin.mainGate(in: graph) : nil)
                }, savedMetadata: saved
            )
            let buildings: [CampusMapContent.Building]
            if case .accepted = outcome {
                buildings = CampusMapContent(bundle: snapshot.bundle).buildings
            } else {
                buildings = []
            }
            return RoutePreview(outcome: outcome, target: summary.map(RoutePreviewTarget.init(summary:)),
                                buildings: buildings, savedMetadata: saved)
        }
        return handler
    }
}

private enum RoutePreviewOrigin {
    static func mainGate(in graph: RoutingGraph) -> RouteOrigin? {
        // 歩行ネットワークの正門ノード（docs/map-data/campus-survey-plan.md）。
        let id = "campus_n_001"
        guard graph.nodes[id]?.location == .campus else { return nil }
        return .node(id: id, displayName: "正門")
    }

    static func nearestNode(to fix: LocationFix?, in graph: RoutingGraph, map: MapGeoJSON) -> RouteOrigin? {
        guard let fix else { return nil }
        let location = CLLocation(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
        var nearest: (id: String, distance: Double)?
        for feature in map.features where graph.nodes[feature.id]?.location == .campus {
            guard let point = feature.point.flatMap(CampusMapCoordinate.init(geoJSONPosition:)) else { continue }
            let distance = location.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            // 誤差の範囲で公開ノードに接続できる場合だけ使う。ノードまでの線や距離は補わない。
            if distance <= fix.horizontalAccuracy, distance < (nearest?.distance ?? .infinity) {
                nearest = (feature.id, distance)
            }
        }
        return nearest.map { .node(id: $0.id, displayName: "現在地付近") }
    }
}
