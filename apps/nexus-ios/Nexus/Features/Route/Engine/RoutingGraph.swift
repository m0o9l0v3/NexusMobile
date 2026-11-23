import Foundation

struct RoutingGraph: Sendable {
    struct Diagnostic: Equatable, Sendable {
        enum Reason: Equatable, Sendable {
            case duplicateID, malformedFeature, selfLoop, invalidWeights, incompatibleEndpoints
            case unknownEndpoint(String)
        }
        let id: String
        let reason: Reason
    }

    let nodes: [String: RoutingNode]
    let destinations: [String: RoutingDestination]
    let entrances: [String: RoutingEdge]
    let primaryEntrances: [String: [RoutingEdge]]
    let adjacency: [String: [RouteStep]]
    let skippedDiagnostics: [Diagnostic]
    private let components: [String: Int]

    init(nodes: [RoutingNode], edges: [RoutingEdge], destinations: [RoutingDestination] = [],
         malformedFeatures: [Diagnostic] = []) {
        // 先勝ち・後勝ちにすると、Feature の並び替えだけで別地点へ案内しうる。
        let ids = nodes.map(\.id) + edges.map(\.id) + destinations.map(\.id) + malformedFeatures.map(\.id)
        var seen = Set<String>()
        var duplicates = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            duplicates.insert(id)
        }
        var diagnostics = malformedFeatures.filter { !duplicates.contains($0.id) }
        diagnostics += duplicates.map { Diagnostic(id: $0, reason: .duplicateID) }
        let uniqueNodes = nodes.filter { !duplicates.contains($0.id) }
        let nodeIndex = Dictionary(uniqueKeysWithValues: uniqueNodes.map { ($0.id, $0) })
        self.nodes = nodeIndex
        self.destinations = Dictionary(uniqueKeysWithValues: destinations.compactMap {
            duplicates.contains($0.id) ? nil : ($0.id, $0)
        })

        var adjacency: [String: [RouteStep]] = [:]
        var neighbors: [String: [String]] = [:]
        var entrances: [String: RoutingEdge] = [:]
        var primaryEntrances: [String: [RoutingEdge]] = [:]
        for edge in edges where !duplicates.contains(edge.id) {
            if let reason = Self.invalidReason(for: edge, nodes: nodeIndex) {
                diagnostics.append(Diagnostic(id: edge.id, reason: reason))
                continue
            }
            adjacency[edge.fromNodeID, default: []].append(RouteStep(edge: edge, isReversed: false))
            if edge.bidirectional {
                adjacency[edge.toNodeID, default: []].append(RouteStep(edge: edge, isReversed: true))
            }
            neighbors[edge.fromNodeID, default: []].append(edge.toNodeID)
            neighbors[edge.toNodeID, default: []].append(edge.fromNodeID)
            if case let .formalEntrance(buildingID, _, isPrimary, _, _) = edge.kind {
                entrances[edge.id] = edge
                if isPrimary { primaryEntrances[buildingID, default: []].append(edge) }
            }
        }

        self.adjacency = adjacency.mapValues { steps in
            steps.sorted { ($0.toNodeID, $0.edge.id) < ($1.toNodeID, $1.edge.id) }
        }
        self.entrances = entrances
        self.primaryEntrances = primaryEntrances
        self.components = Self.connectedComponents(nodes: uniqueNodes, neighbors: neighbors)
        self.skippedDiagnostics = diagnostics.sorted { $0.id < $1.id }
    }

    private static func invalidReason(for edge: RoutingEdge, nodes: [String: RoutingNode]) -> Diagnostic.Reason? {
        guard edge.fromNodeID != edge.toNodeID else { return .selfLoop }
        guard let from = nodes[edge.fromNodeID] else { return .unknownEndpoint(edge.fromNodeID) }
        guard let to = nodes[edge.toNodeID] else { return .unknownEndpoint(edge.toNodeID) }
        let meters = edge.distanceMeters
        let seconds = edge.estimatedSeconds
        guard meters.isFinite, seconds.isFinite, meters >= 0, seconds >= 0 else { return .invalidWeights }
        switch edge.kind {
        case .walkingPath(let location, _):
            guard meters > 0, seconds > 0 else { return .invalidWeights }
            guard from.location == location, to.location == location else { return .incompatibleEndpoints }
        case .formalEntrance(let building, let floor, _, _, _):
            guard meters == 0, seconds == 0 else { return .invalidWeights }
            guard edge.bidirectional, from.location == .campus,
                  to.location == .indoor(buildingID: building, floorID: floor) else { return .incompatibleEndpoints }
        case .transition:
            break
        }
        return nil
    }

    /// 探索方向・通行方針を外したときの連結成分。孤立ノードにも番号を割り当てる。
    private static func connectedComponents(nodes: [RoutingNode], neighbors: [String: [String]]) -> [String: Int] {
        var components: [String: Int] = [:]
        for (index, node) in nodes.enumerated() where components[node.id] == nil {
            var pending = [node.id]
            components[node.id] = index
            while let current = pending.popLast() {
                for next in neighbors[current, default: []] where components[next] == nil {
                    components[next] = index
                    pending.append(next)
                }
            }
        }
        return components
    }

    func areConnected(_ first: String, _ second: String) -> Bool {
        guard let component = components[first] else { return false }
        return component == components[second]
    }
}
