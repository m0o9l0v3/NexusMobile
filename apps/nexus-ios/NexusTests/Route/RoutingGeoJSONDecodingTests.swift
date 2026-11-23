import XCTest
@testable import Nexus

final class RoutingGeoJSONDecodingTests: XCTestCase {
    private typealias F = RoutingTestFixtures

    private func exampleMap() throws -> MapGeoJSON {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../", isDirectory: true).standardizedFileURL
        let body = try Data(contentsOf: root.appendingPathComponent("docs/schemas/examples/participant-bundle-v2.example.json"))
        return try XCTUnwrap(JSONDecoder().decode(ParticipantBundle.self, from: body).map?.geojson)
    }

    func testPublishedExampleRoutesFromLandmarkToRoomWithPublishedCosts() throws {
        let graph = RoutingGraph.build(from: try exampleMap())
        XCTAssertEqual(graph.skippedDiagnostics, [])
        let engine = RoutingEngine(graph: graph)
        let start = "campus_lm_001"
        let end = "mb_1f_cl_001"
        let path = try F.found(engine.findRoute(fromDestination: start, toDestination: end))
        XCTAssertEqual(path.nodeIDs, ["campus_n_030", "campus_n_020", "campus_n_021", "mb_1f_n_004", "mb_1f_n_005"])
        XCTAssertEqual(path.steps.map(\.edge.id), ["campus_e_013", "campus_e_012", "mb_ent_001", "mb_1f_e_001"])
        XCTAssertEqual(path.steps.map(\.isReversed), [true, false, false, false])
        XCTAssertEqual(path.traversedFloorIDs, ["mb_1f"])
        XCTAssertEqual(path.totalDistanceMeters, 57.7, accuracy: 1e-9)
        XCTAssertEqual(path.totalEstimatedSeconds, 53, accuracy: 1e-9)
        let door = path.steps[2].edge
        XCTAssertEqual(door.kind, .formalEntrance(buildingID: "mb", floorID: "mb_1f", isPrimary: true,
                                                 name: "正面入口", openingHours: nil))
        XCTAssertEqual(door.coordinates, [[141.68101, 42.7714]])
        XCTAssertEqual(door.accessibility, .accessible)
        XCTAssertEqual(engine.findRoute(fromDestination: start, toDestination: end, options: F.accessibleOnly),
                       .failure(.unreachable(from: "campus_n_030", to: "mb_1f_n_005")))
    }

    func testDecodeOpeningHoursAndKeepAbsentFieldsOptional() throws {
        let json = """
        {"id":"door","geometry":{"type":"Point","coordinates":[0,0]},
         "properties":{"feature_type":"formal_entrance","opening_hours":"9時から17時"}}
        """
        let feature = try JSONDecoder().decode(MapGeoJSON.Feature.self, from: Data(json.utf8))
        XCTAssertEqual(feature.openingHours, "9時から17時")
        XCTAssertNil(feature.outsideNodeID)
        XCTAssertNil(feature.isPrimary)
        XCTAssertNil(feature.estimatedSeconds)
    }

    func testInvalidGeoJSONEdgesAreDiagnosedWithoutCreatingConnections() throws {
        let map = try exampleMap()
        let nodes = map.features.filter { ["indoor_node", "outdoor_node"].contains($0.featureType) }
        let otherFloor = MapGeoJSON.Feature(id: "upper", featureType: "indoor_node", buildingID: "mb", floorID: "mb_2f",
                                            nodeKind: "junction", geometry: .point([0, 1]))
        // 同じ形状の各辺に異なる配信重みを設定する。形状から距離や時間を補間すると検出できる。
        func path(_ id: String, _ to: String?, from: String = "mb_1f_n_004",
                  meters: Double = 99, seconds: Double = 12) -> MapGeoJSON.Feature {
            .init(id: id, featureType: "walking_path", buildingID: "mb", floorID: "mb_1f", scope: "indoor",
                  fromNodeID: from, toNodeID: to, pathKind: "corridor", bidirectional: false, accessibility: "accessible",
                  distanceMeters: meters, estimatedSeconds: seconds, geometry: .lineString([[0, 0], [0, 1]]))
        }
        let end = "mb_1f_n_005"
        let unknown = MapGeoJSON.Feature(id: "future", featureType: "indoor_transition", geometry: .point([0, 0]))
        let features = nodes + [otherFloor, unknown, path("good", end), path("zero", end, meters: 0),
                                path("negative", end, meters: -1), path("nan", end, meters: .nan),
                                path("inf", end, seconds: .infinity), path("noTime", end, seconds: 0),
                                path("self", end, from: end), path("absent", nil), path("dangling", "missing"),
                                path("cross", "upper"), path("dup", end), path("dup", end, meters: 1)]
        let graph = RoutingGraph.build(from: .init(schemaVersion: map.schemaVersion, floors: map.floors, features: features))
        let expected: [String: RoutingGraph.Diagnostic.Reason] = [
            "zero": .invalidWeights, "negative": .invalidWeights, "nan": .invalidWeights, "inf": .invalidWeights,
            "noTime": .invalidWeights, "self": .selfLoop, "absent": .malformedFeature,
            "dangling": .unknownEndpoint("missing"), "cross": .incompatibleEndpoints, "dup": .duplicateID
        ]
        let diagnostics = expected.map { RoutingGraph.Diagnostic(id: $0.key, reason: $0.value) }
        XCTAssertEqual(graph.skippedDiagnostics, diagnostics.sorted { $0.id < $1.id })
        let engine = RoutingEngine(graph: graph)
        let valid = try F.found(engine.findRoute(from: "mb_1f_n_004", to: end))
        XCTAssertEqual(valid.steps.map(\.edge.id), ["good"])
        XCTAssertEqual(valid.totalDistanceMeters, 99)
        XCTAssertEqual(valid.totalEstimatedSeconds, 12)
        XCTAssertEqual(engine.findRoute(from: end, to: "upper"), .failure(.disconnected(from: end, to: "upper")))
        XCTAssertEqual(engine.findRoute(from: end, to: "mb_1f_n_004"), .failure(.unreachable(from: end, to: "mb_1f_n_004")))
    }

    func testDuplicateNodeAndCrossTypeIDsAreRemovedRegardlessOfInputOrder() {
        let nodes = [F.node("a"), F.node("a"), F.node("b"), F.node("shared")]
        let edges = [F.edge("p", "a", "b"), F.edge("shared", "b", "a")]
        let graph = RoutingGraph(nodes: nodes, edges: edges)
        XCTAssertEqual(Set(graph.nodes.keys), ["b"])
        XCTAssertEqual(graph.skippedDiagnostics, [.init(id: "a", reason: .duplicateID),
                                                 .init(id: "p", reason: .unknownEndpoint("a")),
                                                 .init(id: "shared", reason: .duplicateID)])
        XCTAssertTrue(graph.adjacency.isEmpty)
        XCTAssertEqual(RoutingGraph(nodes: nodes.reversed(), edges: edges.reversed()).skippedDiagnostics,
                       graph.skippedDiagnostics)
    }
}
