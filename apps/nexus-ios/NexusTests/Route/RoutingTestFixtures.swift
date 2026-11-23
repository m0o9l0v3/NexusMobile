import XCTest
@testable import Nexus

/// ID・座標・距離・時間・通行属性はすべて探索テスト用の合成値。現地の実測データではない。
enum RoutingTestFixtures {
    static let first = RoutingLocation.indoor(buildingID: "b", floorID: "1F")
    static let second = RoutingLocation.indoor(buildingID: "b", floorID: "2F")
    static let third = RoutingLocation.indoor(buildingID: "b", floorID: "3F")
    static let accessibleOnly = RoutingOptions(accessibilityPolicy: .accessibleOnly)

    static func node(_ id: String, _ location: RoutingLocation = .campus, kind: String = "junction") -> RoutingNode {
        RoutingNode(id: id, location: location, nodeKind: kind)
    }

    static func edge(_ id: String, _ from: String, _ to: String, meters: Double = 1, seconds: Double = 1,
                     bothWays: Bool = true, access: RoutingAccessibility = .accessible,
                     kind: RoutingEdge.Kind = .walkingPath(location: .campus, pathKind: "walkway"),
                     coordinates: [[Double]] = [[0, 0], [1, 0]]) -> RoutingEdge {
        RoutingEdge(id: id, fromNodeID: from, toNodeID: to, kind: kind, bidirectional: bothWays,
                    accessibility: access, distanceMeters: meters, estimatedSeconds: seconds, coordinates: coordinates)
    }

    static func entrance(_ id: String, _ outside: String, _ inside: String, primary: Bool = true,
                         access: RoutingAccessibility = .accessible) -> RoutingEdge {
        edge(id, outside, inside, meters: 0, seconds: 0, access: access,
             kind: .formalEntrance(buildingID: "b", floorID: "1F", isPrimary: primary, name: id, openingHours: nil),
             coordinates: [[0.5, 0]])
    }

    static func engine(_ nodes: [RoutingNode], _ edges: [RoutingEdge], _ destinations: [RoutingDestination] = []) -> RoutingEngine {
        RoutingEngine(graph: RoutingGraph(nodes: nodes, edges: edges, destinations: destinations))
    }

    static func campus(_ ids: [String], _ edges: [RoutingEdge]) -> RoutingEngine {
        engine(ids.map { node($0) }, edges)
    }

    static func found(_ result: RouteSearchResult, file: StaticString = #filePath, line: UInt = #line) throws -> RoutePath {
        if case .found(let path) = result { return path }
        return try XCTUnwrap(nil, "通常経路を期待したが \(result)", file: file, line: line)
    }

    static func assertSamePoint(_ result: RouteSearchResult, at id: String, floors: [String] = [],
                                file: StaticString = #filePath, line: UInt = #line) {
        let emptyPath = RoutePath(startNodeID: id, destinationNodeID: id, nodeIDs: [id], steps: [],
                                  totalDistanceMeters: 0, totalEstimatedSeconds: 0, traversedFloorIDs: floors)
        XCTAssertTrue(emptyPath.isSamePoint, file: file, line: line)
        XCTAssertEqual(result, .samePoint(emptyPath), file: file, line: line)
    }
}
