import XCTest
@testable import Nexus

final class RoutingEngineTests: XCTestCase {
    private typealias F = RoutingTestFixtures

    func testMetricChoosesMinimumWeightAndReportsBothTotals() throws {
        let engine = F.campus(["a", "b", "c"], [
            F.edge("direct", "a", "c", meters: 9, seconds: 1.5),
            F.edge("first", "a", "b", meters: 1.1, seconds: 3.6),
            F.edge("next", "b", "c", meters: 1.2, seconds: 4.8)
        ])
        let shortest = try F.found(engine.findRoute(from: "a", to: "c"))
        XCTAssertEqual(shortest.nodeIDs, ["a", "b", "c"])
        XCTAssertFalse(shortest.isSamePoint)
        XCTAssertEqual(shortest.totalDistanceMeters, 2.3, accuracy: 1e-9)
        XCTAssertEqual(shortest.totalEstimatedSeconds, 8.4, accuracy: 1e-9)
        let fastest = try F.found(engine.findRoute(from: "a", to: "c", options: .init(metric: .estimatedTime)))
        XCTAssertEqual(fastest.steps.map(\.edge.id), ["direct"])
        XCTAssertEqual(fastest.totalDistanceMeters, 9)
        XCTAssertEqual(fastest.totalEstimatedSeconds, 1.5)
    }

    func testTiesPreferSecondaryCostThenFewerSteps() throws {
        let engine = F.campus(["a", "b", "c"], [
            F.edge("z", "a", "c", meters: 2, seconds: 2),
            F.edge("a-slow", "a", "c", meters: 2, seconds: 3),
            F.edge("a-long", "a", "c", meters: 3, seconds: 2),
            F.edge("a-first", "a", "b"), F.edge("b-last", "b", "c")
        ])
        for metric in [RoutingCostMetric.distance, .estimatedTime] {
            let path = try F.found(engine.findRoute(from: "a", to: "c", options: .init(metric: metric)))
            XCTAssertEqual(path.steps.map(\.edge.id), ["z"])
        }
    }

    func testEqualCostsUseWholeEdgeIDSequenceRegardlessOfInputOrder() throws {
        let ids = ["s", "a", "b", "t"]
        let edges = [F.edge("b-first", "s", "a"), F.edge("a-last", "a", "t"),
                     F.edge("a-first", "s", "b"), F.edge("z-last", "b", "t")]
        for ordering in [edges, edges.reversed(), Array(edges[2...]) + Array(edges[..<2])] {
            let engine = F.campus(ids.reversed(), ordering)
            let path = try F.found(engine.findRoute(from: "s", to: "t"))
            XCTAssertEqual(path.steps.map(\.edge.id), ["a-first", "z-last"])
        }
    }

    func testLineStringFollowsTravelDirectionIncludingIntermediatePoint() throws {
        let coords = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
        let engine = F.campus(["A", "a"], [F.edge("p", "A", "a", coordinates: coords)])
        for (start, end, points) in [("A", "a", coords), ("a", "A", coords.reversed())] {
            let path = try F.found(engine.findRoute(from: start, to: end))
            XCTAssertEqual(path.startNodeID, start)
            XCTAssertEqual(path.destinationNodeID, end)
            XCTAssertEqual(path.steps.first?.fromNodeID, start)
            XCTAssertEqual(path.steps.first?.toNodeID, end)
            XCTAssertEqual(path.steps.first?.coordinates, points)
        }
        XCTAssertEqual(engine.findRoute(from: "Z", to: "A"), .failure(.unknownNode("Z")))
        XCTAssertEqual(engine.findRoute(from: "A", to: "Z"), .failure(.unknownNode("Z")))
        XCTAssertEqual(engine.findRoute(from: "Z", to: "Z"), .failure(.unknownNode("Z")))
    }

    func testSamePointWithAndWithoutNeighbors() {
        let engine = F.campus(["a", "b", "lone"], [F.edge("p", "a", "b")])
        for id in ["a", "lone"] { F.assertSamePoint(engine.findRoute(from: id, to: id), at: id) }
    }

    func testIsolatedNodeAndSeparateComponentAreDisconnected() {
        let engine = F.campus(["a", "b", "c", "d", "lone"], [F.edge("p", "a", "b"), F.edge("q", "c", "d")])
        for id in ["c", "lone"] {
            XCTAssertEqual(engine.findRoute(from: "a", to: id), .failure(.disconnected(from: "a", to: id)))
        }
    }

    func testOneWayEdgeAndDirectedDetour() throws {
        let edge = F.edge("one", "a", "b", bothWays: false)
        let engine = F.campus(["a", "b"], [edge])
        XCTAssertEqual(try F.found(engine.findRoute(from: "a", to: "b")).steps.map(\.edge.id), ["one"])
        XCTAssertEqual(engine.findRoute(from: "b", to: "a"), .failure(.unreachable(from: "b", to: "a")))
        let detour = F.campus(["a", "b", "c"], [edge, F.edge("back1", "b", "c", bothWays: false),
                                               F.edge("back2", "c", "a", bothWays: false)])
        XCTAssertEqual(try F.found(detour.findRoute(from: "b", to: "a")).nodeIDs, ["b", "c", "a"])
    }

    func testAccessibleOnlyAvoidsUnconfirmedAndInaccessiblePaths() throws {
        for access in [RoutingAccessibility.unknown, .notAccessible] {
            let short = F.edge("short", "a", "c", access: access)
            let engine = F.campus(["a", "b", "c"], [short, F.edge("p", "a", "b"), F.edge("q", "b", "c")])
            XCTAssertEqual(try F.found(engine.findRoute(from: "a", to: "c")).steps.map(\.edge.id), ["short"])
            let route = try F.found(engine.findRoute(from: "a", to: "c", options: F.accessibleOnly))
            XCTAssertEqual(route.nodeIDs, ["a", "b", "c"])
            XCTAssertEqual(F.campus(["a", "c"], [short]).findRoute(from: "a", to: "c", options: F.accessibleOnly),
                           .failure(.unreachable(from: "a", to: "c")))
        }
    }

    func testZeroCostParallelEntrancesWorkInBothDirectionsAndRespectAccessibility() throws {
        let engine = F.engine([F.node("o"), F.node("i", F.first), F.node("room", F.first)], [
            F.entrance("a-main", "o", "i", access: .notAccessible), F.entrance("b-side", "o", "i", primary: false),
            F.edge("hall", "i", "room", kind: .walkingPath(location: F.first, pathKind: "corridor"))
        ])
        for (start, end) in [("o", "i"), ("i", "o")] {
            for (options, door) in [(RoutingOptions(), "a-main"), (F.accessibleOnly, "b-side")] {
                let path = try F.found(engine.findRoute(from: start, to: end, options: options))
                XCTAssertEqual(path.steps.map(\.edge.id), [door])
                XCTAssertEqual(path.totalDistanceMeters, 0)
                XCTAssertEqual(path.totalEstimatedSeconds, 0)
                XCTAssertFalse(path.isSamePoint)
                XCTAssertEqual(path.traversedFloorIDs, ["1F"])
            }
        }
        let beyondEntrances = try F.found(engine.findRoute(from: "o", to: "room"))
        XCTAssertEqual(beyondEntrances.nodeIDs, ["o", "i", "room"])
        XCTAssertEqual(beyondEntrances.steps.map(\.edge.id), ["a-main", "hall"])
    }

    func testSameFloorAndOutdoorToUpperFloorsViaAbstractTransitions() throws {
        let engine = F.engine([F.node("o"), F.node("i", F.first), F.node("a", F.first),
                               F.node("b", F.second), F.node("c", F.third), F.node("isolated", .indoor(buildingID: "b", floorID: "4F"))], [
            F.entrance("door", "o", "i"),
            F.edge("hall", "i", "a", kind: .walkingPath(location: F.first, pathKind: "corridor")),
            F.edge("stairs", "a", "b", access: .notAccessible, kind: .transition(label: "階段")),
            F.edge("lift", "a", "b", meters: 3, kind: .transition(label: "EV")),
            F.edge("up", "b", "c", bothWays: false, kind: .transition(label: "上り"))
        ])
        let hall = try F.found(engine.findRoute(from: "i", to: "a"))
        XCTAssertEqual(hall.traversedFloorIDs, ["1F"])
        XCTAssertEqual(hall.steps.map(\.edge.id), ["hall"])
        let path = try F.found(engine.findRoute(from: "o", to: "c"))
        XCTAssertEqual(path.steps.map(\.edge.id), ["door", "hall", "stairs", "up"])
        XCTAssertEqual(path.traversedFloorIDs, ["1F", "2F", "3F"])
        let lift = try F.found(engine.findRoute(from: "o", to: "b", options: F.accessibleOnly))
        XCTAssertEqual(lift.steps.map(\.edge.id), ["door", "hall", "lift"])
        XCTAssertEqual(lift.traversedFloorIDs, ["1F", "2F"])
        XCTAssertEqual(engine.findRoute(from: "c", to: "b"), .failure(.unreachable(from: "c", to: "b")))
        XCTAssertEqual(engine.findRoute(from: "o", to: "isolated"), .failure(.disconnected(from: "o", to: "isolated")))
    }

    func testUnknownElevatorCannotProvideAccessibleConnection() {
        let engine = F.engine([F.node("a", F.first), F.node("b", F.second)], [
            F.edge("stairs", "a", "b", access: .notAccessible, kind: .transition(label: "階段")),
            F.edge("lift", "a", "b", access: .unknown, kind: .transition(label: "EV"))
        ])
        XCTAssertEqual(engine.findRoute(from: "a", to: "b", options: F.accessibleOnly),
                       .failure(.unreachable(from: "a", to: "b")))
    }
}
