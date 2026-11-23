import XCTest
@testable import Nexus

final class OutdoorRouteStepTests: XCTestCase {
    private typealias Builder = OutdoorRouteStepBuilder
    private typealias F = RoutingTestFixtures

    private func path(_ edges: [RoutingEdge], reversed: Bool = false) -> RoutePath {
        let steps = (reversed ? edges.reversed() : edges).map { RouteStep(edge: $0, isReversed: reversed) }
        return .init(startNodeID: steps.first?.fromNodeID ?? "a", destinationNodeID: steps.last?.toNodeID ?? "b",
                     nodeIDs: [steps.first?.fromNodeID ?? "a"] + steps.map(\.toNodeID), steps: steps,
                     totalDistanceMeters: edges.reduce(0) { $0 + $1.distanceMeters }, totalEstimatedSeconds: 0,
                     traversedFloorIDs: [])
    }

    func testSignedAngleAndDirectionBoundaries() throws {
        let origin = CampusMapCoordinate(latitude: 43, longitude: 141)
        let south = CampusMapCoordinate(latitude: 42.999, longitude: 141)
        let cases: [(Double, RouteTurnDirection, RouteTurnDirection)] = [
            (0, .straight, .straight), (24.9, .straight, .straight), (25, .slightRight, .slightLeft),
            (44.9, .slightRight, .slightLeft), (45, .right, .left), (90, .right, .left),
            (149.9, .right, .left), (150, .uTurn, .uTurn), (180, .uTurn, .uTurn)
        ]
        for (magnitude, right, left) in cases {
            for (degrees, expected) in [(magnitude, right), (-magnitude, left)] {
                XCTAssertEqual(Builder.turnDirection(forSignedDegrees: degrees), expected)
                let radians = degrees * .pi / 180
                let exit = CampusMapCoordinate(latitude: 43 + 0.001 * cos(radians),
                    longitude: 141 + 0.001 * sin(radians) / cos(43 * .pi / 180))
                let forward = try XCTUnwrap(Builder.signedTurnDegrees(from: south, via: origin, to: exit))
                let reverse = try XCTUnwrap(Builder.signedTurnDegrees(from: exit, via: origin, to: south))
                XCTAssertEqual(forward, magnitude == 180 ? 180 : degrees, accuracy: 1e-8)
                XCTAssertEqual(reverse, magnitude == 180 ? 180 : -forward, accuracy: 1e-8)
            }
        }
        XCTAssertNil(Builder.signedTurnDegrees(from: origin, via: origin, to: south))
        let near = CampusMapCoordinate(latitude: 43.000001, longitude: 141)
        XCTAssertNil(Builder.signedTurnDegrees(from: south, via: origin, to: near))
        let equator = CampusMapCoordinate(latitude: 0, longitude: 0)
        let west = CampusMapCoordinate(latitude: 0, longitude: -0.001)
        let almostWest = CampusMapCoordinate(latitude: 1e-15, longitude: -0.001)
        XCTAssertEqual(Builder.signedTurnDegrees(from: west, via: equator, to: almostWest), 180)
    }

    func testFixtureInteriorTurnsAndDistanceSharesInBothDirections() throws {
        let map = try XCTUnwrap(RouteCheckFixtures.bundle.map?.geojson)
        let graph = RoutingGraph.build(from: map)
        let step = try XCTUnwrap(graph.adjacency["campus_n_030"]?.first { $0.toNodeID == "campus_n_031" })
        let markers = Builder.landmarksByNodeID(in: RouteCheckFixtures.bundle)
        for reversed in [false, true] {
            let steps = Builder.buildSteps(from: path([step.edge], reversed: reversed), landmarksByNodeID: markers)
            XCTAssertEqual(steps.map(\.vertexSource), [.origin, .edgeInterior, .edgeInterior, .destination])
            guard steps.count == 4 else { return }
            XCTAssertEqual(steps.map(\.kind), [.depart(fromIndoor: false), .turn(.right), .turn(.left), .arrive(continuesIndoors: false)])
            XCTAssertEqual(try XCTUnwrap(steps[1].turnAngleDegrees), reversed ? 90 : 47.75467, accuracy: 0.0001)
            XCTAssertEqual(try XCTUnwrap(steps[2].turnAngleDegrees), reversed ? -47.75467 : -90, accuracy: 0.0001)
            for turn in steps[1...2] {
                XCTAssertNil(turn.nodeID)
                XCTAssertNil(turn.landmark)
                XCTAssertNotNil(turn.coordinate)
            }
            let shares = [41.63186, 100.76159, 85.60655]
            let distances = steps.compactMap(\.distanceMeters)
            for (value, expected) in zip(distances, reversed ? shares.reversed() : shares) {
                XCTAssertEqual(value, expected, accuracy: 0.0001)
            }
            XCTAssertEqual(distances.reduce(0, +), 228, accuracy: 1e-9)
            XCTAssertNil(steps.last?.distanceMeters)
        }
    }

    func testEdgeJunctionsKeepPublishedDistancesAndNamedNodeInBothDirections() throws {
        let edges = [F.edge("e", "a", "b", meters: 17, coordinates: [[0, 0], [0, 0.001]]),
                     F.edge("f", "b", "c", meters: 23, coordinates: [[0, 0.001], [0.001, 0.001]])]
        let sign = OutdoorRouteLandmark(id: "sign", name: "案内板", source: .landmark)
        for reversed in [false, true] {
            let steps = Builder.buildSteps(from: path(edges, reversed: reversed), landmarksByNodeID: ["b": sign])
            XCTAssertEqual(steps.map(\.vertexSource), [.origin, .edgeJunction, .destination])
            let turn = try XCTUnwrap(steps.first { $0.vertexSource == .edgeJunction })
            XCTAssertEqual(turn.kind, .turn(reversed ? .left : .right))
            XCTAssertEqual(turn.nodeID, "b")
            XCTAssertEqual(turn.landmark, sign)
            XCTAssertEqual(turn.titleText, reversed ? "案内板で左へ曲がる" : "案内板で右へ曲がる")
            XCTAssertEqual(steps.compactMap(\.distanceMeters), reversed ? [23, 17] : [17, 23])
        }
    }

    func testSmallBendsAndStraightJunctionsAccumulateDistanceAndUniquePassedLandmarks() throws {
        // 方位角の差は順に +12°, -18°, +20°, 0°。
        var point = [0.0, 0.0]
        let bearings = [0.0, 12, -6, 14, 14]
        let edges = bearings.enumerated().map { i, bearing in
            let angle = bearing * .pi / 180
            let next = [point[0] + 0.001 * sin(angle), point[1] + 0.001 * cos(angle)]
            defer { point = next }
            return F.edge("e\(i)", "n\(i)", "n\(i + 1)", meters: 12, coordinates: [point, next])
        }
        let start = OutdoorRouteLandmark(id: "gate", name: "門", source: .landmark)
        let sign = OutdoorRouteLandmark(id: "sign", name: "案内板", source: .landmark)
        let end = OutdoorRouteLandmark(id: "entrance", name: "教室棟 正面入口", source: .formalEntrance)
        let markers = ["n0": start, "n1": start, "n2": sign, "n3": sign, "n4": end, "n5": end]
        let steps = Builder.buildSteps(from: path(edges), destinationName: "教室棟", landmarksByNodeID: markers)
        XCTAssertEqual(steps.map(\.kind), [.depart(fromIndoor: false), .arrive(continuesIndoors: false)])
        let first = try XCTUnwrap(steps.first), last = try XCTUnwrap(steps.last)
        XCTAssertEqual(first.passedLandmarks, [sign])
        XCTAssertEqual(first.distanceMeters, 60)
        XCTAssertEqual(first.landmarkNoteText, "通過：案内板")
        XCTAssertEqual(last.landmarkNoteText, "目印：教室棟 正面入口")
        XCTAssertEqual(RouteAccessibilityText.outdoorStepsToggle(count: 2), "屋外のステップ、2件")
        XCTAssertEqual(RouteAccessibilityText.outdoorStep(first, totalCount: 2), "全2件中1件目、門から進む、60 m、通過：案内板")
        XCTAssertEqual(RouteAccessibilityText.outdoorStep(last, totalCount: 2), "全2件中2件目、教室棟に到着、目印：教室棟 正面入口")
    }

    func testInvalidDuplicateAndSubHalfMeterPointsDoNotCreateTurns() {
        let points: [[Double]] = [[], [0], [0, 0], [0, 0], [.infinity, 0], [0, .nan], [181, 0], [0, 91],
                                  [0, 0.000002], [0.001, 0], [0.001, 0.000002], [0.002, 0]]
        let steps = Builder.buildSteps(from: path([F.edge("e", "a", "b", meters: 73, coordinates: points)]))
        XCTAssertEqual(steps.map(\.kind), [.depart(fromIndoor: false), .arrive(continuesIndoors: false)])
        XCTAssertEqual(steps.first?.distanceMeters, 73)
    }

    func testDegenerateEdgesKeepTheirDistanceWithoutInventingATurn() {
        let missing = F.edge("missing", "b", "c", meters: 13, coordinates: [])
        let repeated = F.edge("repeat", "c", "d", meters: 17, coordinates: [[0, 0], [0, 0]])
        let steps = Builder.buildSteps(from: path([missing, repeated]))
        XCTAssertEqual(steps.map(\.titleText), ["出発地から進む", "目的地に到着"])
        XCTAssertEqual(steps.compactMap(\.distanceMeters), [30])
        XCTAssertNil(steps.first?.coordinate)
        let before = F.edge("before", "a", "b", meters: 20, coordinates: [[0, 0], [0.001, 0]])
        let after = F.edge("after", "d", "e", meters: 10, coordinates: [[0.001, 0], [0.001, 0.001]])
        let route = Builder.buildSteps(from: path([before, missing, repeated, after]))
        XCTAssertEqual(route.compactMap(\.distanceMeters), [60])
    }

    func testEmptySamePointAndIndoorOnlyPathsHaveNoOutdoorSteps() {
        let indoor = F.edge("i", "a", "b", kind: .walkingPath(location: F.first, pathKind: "corridor"))
        for edges in [[], [indoor], [F.entrance("door", "a", "b")], [F.edge("loop", "a", "a")]] {
            XCTAssertTrue(Builder.buildSteps(from: path(edges)).isEmpty)
        }
    }

    func testAbstractTransitionAloneDoesNotIdentifyAnIndoorEntrance() {
        let transition = F.edge("t", "x", "a", kind: .transition(label: "遷移"), coordinates: [])
        let outdoor = F.edge("e", "a", "b", meters: 8)
        let result = Builder.buildSteps(from: path([transition, outdoor]), originName: "別の出発地点")
        XCTAssertEqual(result.map(\.kind), [.depart(fromIndoor: false), .arrive(continuesIndoors: false)])
        XCTAssertEqual(result.first?.nodeID, "a")
        XCTAssertEqual(result.first?.titleText, "出発地から進む")
    }

    func testSeparatedOutdoorSectionsStartAgainAtTheOutsideNode() {
        let edges = [F.edge("e", "a", "b", meters: 11, coordinates: [[0, 0], [0.001, 0]]),
                     F.entrance("entry", "b", "inside1"),
                     F.edge("hall", "inside1", "inside2", meters: 88, kind: .walkingPath(location: F.first, pathKind: "corridor")),
                     F.edge("f", "d", "e", meters: 19, coordinates: [[0.002, 0], [0.002, 0.001]])]
        let exit = RouteStep(edge: F.entrance("exit", "d", "inside2"), isReversed: true)
        var steps = edges.map { RouteStep(edge: $0, isReversed: false) }
        steps.insert(exit, at: 3)
        let route = RoutePath(startNodeID: "a", destinationNodeID: "e", nodeIDs: ["a"] + steps.map(\.toNodeID),
                              steps: steps, totalDistanceMeters: 118, totalEstimatedSeconds: 10, traversedFloorIDs: ["1F"])
        let sign = OutdoorRouteLandmark(id: "west", name: "西口", source: .formalEntrance)
        let result = Builder.buildSteps(from: route, originName: "正門", destinationName: "広場", landmarksByNodeID: ["d": sign])
        XCTAssertEqual(result.map(\.titleText), ["正門から進む", "建物の入口に到着（以降は屋内）", "西口から屋外へ進む", "広場に到着"])
        XCTAssertEqual(result.map(\.nodeID), ["a", "b", "d", "e"])
        XCTAssertEqual(result.compactMap(\.distanceMeters), [11, 19])
        XCTAssertEqual(result.map(\.index), [1, 2, 3, 4])
        XCTAssertEqual(result.map(\.id), (1...4).map { "outdoor-step-\($0)" })
    }

    func testOnlyExplicitNamesAreResolvedInStablePriorityOrder() throws {
        func feature(_ id: String, _ type: String, _ properties: [String: String]) -> [String: Any] {
            ["id": id, "geometry": ["type": "Point", "coordinates": [141.0, 43.0]],
             "properties": properties.merging(["feature_type": type]) { _, type in type }]
        }
        func door(_ id: String, _ node: String, _ name: String, building: String = "mb") -> [String: Any] {
            feature(id, "formal_entrance", ["outside_node_id": node, "name": name, "building_id": building])
        }
        let features = [
            feature("lm_b", "landmark", ["access_node_id": "n1"]),
            feature("lm_a", "landmark", ["access_node_id": "n1"]),
            feature("n1", "outdoor_node", ["name": "分岐点"]), door("d1", "n1", "東口"),
            feature("unpublished", "landmark", ["access_node_id": "n2", "name": "未公開"]),
            feature("n2", "outdoor_node", ["name": "時計台"]),
            door("d_b", "n3", "南口"), door("d_a", "n3", "西口"), feature("n3", "outdoor_node", ["name": "分岐"]),
            door("d4", "n4", "教室棟 正門"), door("d5", "n5", "　 "), door("d6", "n6", "仮名"),
            door("d7", "n7", " ", building: "absent"), door("d8", "n8", "北門", building: "absent"),
            feature("n9", "outdoor_node", ["name": " \n "]), feature("n10", "outdoor_node", [:]),
            feature("lm_empty", "landmark", ["access_node_id": "n11"])
        ]
        let spots = [("lm_a", "広場"), ("lm_b", "庭園"), ("d6", "公開名"), ("lm_empty", "　")]
            .map { BundleFixtures.spot(id: $0.0, name: $0.1) }
        for ordered in [features, features.reversed()] {
            let map: [String: Any] = ["dataset_version": 1, "dataset_sha256": String(repeating: "0", count: 64),
                                      "geojson": BundleFixtures.geojson(extraFeatures: ordered)]
            let data = BundleFixtures.data(BundleFixtures.bundleObject(spots: spots, map: map))
            let result = Builder.landmarksByNodeID(in: try JSONDecoder().decode(ParticipantBundle.self, from: data))
            XCTAssertEqual(result["n1"], .init(id: "lm_a", name: "広場", source: .landmark))
            XCTAssertEqual(result["n2"], .init(id: "n2", name: "時計台", source: .outdoorNode))
            XCTAssertEqual(result["n3"], .init(id: "d_a", name: "教室棟 西口", source: .formalEntrance))
            XCTAssertEqual(result["n4"]?.name, "教室棟 正門")
            XCTAssertEqual(result["n5"]?.name, "教室棟")
            XCTAssertEqual(result["n6"]?.name, "公開名")
            XCTAssertEqual(result["n8"]?.name, "北門")
            XCTAssertEqual(Set(result.keys), Set(["n1", "n2", "n3", "n4", "n5", "n6", "n8"]))
        }
    }
}
