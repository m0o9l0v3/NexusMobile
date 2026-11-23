import Foundation

struct RoutingEngine: Sendable {
    let graph: RoutingGraph

    func resolveDestinationNode(for id: String, approach: RoutingApproach) -> Result<String, RouteFailureReason> {
        if let entrance = graph.entrances[id],
           case let .formalEntrance(buildingID, _, _, _, _) = entrance.kind {
            return .success(approach == .fromIndoor(buildingID: buildingID) ? entrance.toNodeID : entrance.fromNodeID)
        }
        guard let destination = graph.destinations[id] else { return .failure(.unknownDestination(id)) }
        guard let accessID = destination.accessNodeID else {
            if case .building = destination.kind {
                let entrances = graph.primaryEntrances[id, default: []]
                if entrances.count > 1 { return .failure(.notRoutable(.ambiguousPrimaryEntrance)) }
                if let primary = entrances.first { return .success(primary.fromNodeID) }
            }
            return .failure(.notRoutable(.missingAccessNode))
        }

        guard let node = graph.nodes[accessID], node.nodeKind == "destination" else {
            return .failure(.notRoutable(.invalidAccessNode(accessID)))
        }
        switch (destination.kind, node.location) {
        case (.landmark, .campus):
            return .success(accessID)
        case let (.room(building, floor), .indoor(nodeBuilding, nodeFloor))
            where building == nodeBuilding && floor == nodeFloor:
            return .success(accessID)
        case let (.building, .indoor(nodeBuilding, _)) where id == nodeBuilding:
            return .success(accessID)
        default:
            return .failure(.notRoutable(.invalidAccessNode(accessID)))
        }
    }

    func findRoute(fromDestination start: String, toDestination end: String,
                   approach: RoutingApproach = .fromOutdoor, options: RoutingOptions = .init()) -> RouteSearchResult {
        switch resolveDestinationNode(for: start, approach: approach) {
        case .failure(let reason): return .failure(reason)
        case .success(let nodeID): return findRoute(from: nodeID, toDestination: end, options: options)
        }
    }

    func findRoute(from start: String, toDestination end: String, options: RoutingOptions = .init()) -> RouteSearchResult {
        guard let node = graph.nodes[start] else { return .failure(.unknownNode(start)) }
        let approach: RoutingApproach
        switch node.location {
        case .campus: approach = .fromOutdoor
        case .indoor(let buildingID, _): approach = .fromIndoor(buildingID: buildingID)
        }
        switch resolveDestinationNode(for: end, approach: approach) {
        case .failure(let reason): return .failure(reason)
        case .success(let endNodeID): return findRoute(from: start, to: endNodeID, options: options)
        }
    }

    func findRoute(from start: String, to end: String, options: RoutingOptions = .init()) -> RouteSearchResult {
        guard graph.nodes[start] != nil else { return .failure(.unknownNode(start)) }
        guard graph.nodes[end] != nil else { return .failure(.unknownNode(end)) }
        if start == end { return .samePoint(path(from: start, to: end, steps: [])) }
        guard graph.areConnected(start, end) else { return .failure(.disconnected(from: start, to: end)) }

        var best = [start: PathCost()]
        var previous: [String: RouteStep] = [:]
        var queue = BinaryHeap<Candidate>()
        queue.insert(Candidate(nodeID: start, cost: PathCost()))
        while let current = queue.popMinimum() {
            // 改善前にキューへ入れた候補を展開しない。
            guard current.cost == best[current.nodeID] else { continue }
            if current.nodeID == end {
                var steps: [RouteStep] = []
                var nodeID = end
                while let step = previous[nodeID] {
                    steps.append(step)
                    nodeID = step.fromNodeID
                }
                return .found(path(from: start, to: end, steps: steps.reversed()))
            }
            for step in graph.adjacency[current.nodeID, default: []] where options.accessibilityPolicy.allows(step.edge.accessibility) {
                let cost = current.cost.appending(step.edge, metric: options.metric)
                let nextID = step.toNodeID
                if let known = best[nextID], known <= cost { continue }
                best[nextID] = cost
                previous[nextID] = step
                queue.insert(Candidate(nodeID: nextID, cost: cost))
            }
        }
        return .failure(.unreachable(from: start, to: end))
    }

    private func path(from start: String, to end: String, steps: [RouteStep]) -> RoutePath {
        let nodeIDs = [start] + steps.map(\.toNodeID)
        var floors: [String] = []
        for id in nodeIDs {
            if case let .indoor(_, floorID) = graph.nodes[id]?.location, floors.last != floorID {
                floors.append(floorID)
            }
        }
        return RoutePath(startNodeID: start, destinationNodeID: end, nodeIDs: nodeIDs, steps: steps,
                         totalDistanceMeters: steps.reduce(0) { $0 + $1.edge.distanceMeters },
                         totalEstimatedSeconds: steps.reduce(0) { $0 + $1.edge.estimatedSeconds },
                         traversedFloorIDs: floors)
    }
}

private struct PathCost: Comparable, Sendable {
    var primary: Double = 0
    var secondary: Double = 0
    var edgeIDs: [String] = []
    var hops: Int { edgeIDs.count }

    func appending(_ edge: RoutingEdge, metric: RoutingCostMetric) -> Self {
        var next = self
        next.primary += metric == .distance ? edge.distanceMeters : edge.estimatedSeconds
        next.secondary += metric == .distance ? edge.estimatedSeconds : edge.distanceMeters
        next.edgeIDs.append(edge.id)
        return next
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.primary != rhs.primary { return lhs.primary < rhs.primary }
        if lhs.secondary != rhs.secondary { return lhs.secondary < rhs.secondary }
        if lhs.hops != rhs.hops { return lhs.hops < rhs.hops }
        return lhs.edgeIDs.lexicographicallyPrecedes(rhs.edgeIDs)
    }
}

private struct Candidate: Comparable, Sendable {
    let nodeID: String
    let cost: PathCost

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.cost == rhs.cost { return lhs.nodeID < rhs.nodeID }
        return lhs.cost < rhs.cost
    }
}
