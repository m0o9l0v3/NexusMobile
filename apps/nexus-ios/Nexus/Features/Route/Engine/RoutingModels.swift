import Foundation

enum RoutingLocation: Equatable, Sendable {
    case campus
    case indoor(buildingID: String, floorID: String)
}

struct RoutingNode: Equatable, Sendable {
    let id: String
    let location: RoutingLocation
    let nodeKind: String
}

enum RoutingAccessibility: String, Sendable {
    case accessible
    case notAccessible = "not_accessible"
    case unknown
}

enum RoutingAccessibilityPolicy: Sendable {
    case standard, accessibleOnly

    func allows(_ accessibility: RoutingAccessibility) -> Bool {
        self == .standard || accessibility == .accessible
    }
}

enum RoutingCostMetric: Sendable {
    case distance, estimatedTime
}

struct RoutingOptions: Sendable {
    var metric: RoutingCostMetric = .distance
    var accessibilityPolicy: RoutingAccessibilityPolicy = .standard
}

struct RoutingEdge: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case walkingPath(location: RoutingLocation, pathKind: String)
        case formalEntrance(buildingID: String, floorID: String, isPrimary: Bool, name: String?, openingHours: String?)
        /// 直接構築したグラフで使う遷移。配信データとの対応は #42 で定める。
        case transition(label: String)
    }

    let id: String
    let fromNodeID: String
    let toNodeID: String
    let kind: Kind
    let bidirectional: Bool
    let accessibility: RoutingAccessibility
    let distanceMeters: Double
    let estimatedSeconds: Double
    /// [経度, 緯度]。正式入口は閾値の1点。
    let coordinates: [[Double]]
}

/// 正式入口はグラフ上の辺がそのまま目的地を兼ねる。
struct RoutingDestination: Sendable {
    enum Kind: Sendable {
        case building
        case room(buildingID: String, floorID: String)
        case landmark
    }

    let id: String
    let kind: Kind
    let accessNodeID: String?
}

enum RoutingApproach: Equatable, Sendable {
    case fromOutdoor
    case fromIndoor(buildingID: String)
}

struct RouteStep: Equatable, Sendable {
    let edge: RoutingEdge
    let isReversed: Bool

    var fromNodeID: String { isReversed ? edge.toNodeID : edge.fromNodeID }
    var toNodeID: String { isReversed ? edge.fromNodeID : edge.toNodeID }
    var coordinates: [[Double]] { isReversed ? edge.coordinates.reversed() : edge.coordinates }
}

struct RoutePath: Equatable, Sendable {
    let startNodeID: String
    let destinationNodeID: String
    let nodeIDs: [String]
    let steps: [RouteStep]
    let totalDistanceMeters: Double
    let totalEstimatedSeconds: Double
    let traversedFloorIDs: [String]

    var isSamePoint: Bool { startNodeID == destinationNodeID }
}

enum RouteFailureReason: Error, Equatable, Sendable {
    enum NotRoutable: Equatable, Sendable {
        case missingAccessNode, ambiguousPrimaryEntrance
        case invalidAccessNode(String)
    }

    case unknownNode(String)
    case unknownDestination(String)
    case notRoutable(NotRoutable)
    case disconnected(from: String, to: String)
    case unreachable(from: String, to: String)
}

enum RouteSearchResult: Equatable, Sendable {
    case found(RoutePath)
    case samePoint(RoutePath)
    case failure(RouteFailureReason)
}
