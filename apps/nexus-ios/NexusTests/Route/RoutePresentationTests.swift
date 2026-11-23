import XCTest
@testable import Nexus

final class RoutePresentationTests: XCTestCase {
    private typealias F = RoutingTestFixtures
    private let indoor = RoutePolylineSegment.Scope.indoor(buildingID: "b", floorID: "1F")

    private func path(_ steps: [RouteStep]) -> RoutePath {
        RoutePath(startNodeID: steps.first?.fromNodeID ?? "a", destinationNodeID: steps.last?.toNodeID ?? "a",
                  nodeIDs: [steps.first?.fromNodeID ?? "a"] + steps.map(\.toNodeID), steps: steps,
                  totalDistanceMeters: 57.7, totalEstimatedSeconds: 53, traversedFloorIDs: [])
    }

    private func coordinate(_ longitude: Double, _ latitude: Double = 1) -> CampusMapCoordinate {
        .init(latitude: latitude, longitude: longitude)
    }

    private func route(points: [CampusMapCoordinate], start: CampusMapCoordinate? = nil,
                       end: CampusMapCoordinate? = nil) -> ResolvedRoute {
        ResolvedRoute(origin: .init(id: "a", displayName: nil, coordinate: start),
                      destination: .init(id: "b", displayName: "格納庫", coordinate: end),
                      path: path([]), segments: [.init(id: "s", scope: .outdoor, coordinates: points)],
                      traversedFloorLabels: [], bundleVersion: 1)
    }

    func testWalkingStepsFollowTravelDirectionAndRemoveOnlyConsecutiveDuplicates() {
        let edge = F.edge("e", "a", "b", coordinates: [[1, 1], [1, 1], [2, 3], [1, 1], [4, 5]])
        let next = F.edge("f", "b", "c", coordinates: [[4, 5], [6, 7]])
        let expected = [coordinate(1), coordinate(2, 3), coordinate(1), coordinate(4, 5), coordinate(6, 7)]
        for reversed in [false, true] {
            let edges = reversed ? [next, edge] : [edge, next]
            let segments = RoutePolylineBuilder.buildSegments(from: path(edges.map { .init(edge: $0, isReversed: reversed) }))
            XCTAssertEqual(segments.map(\.scope), [.outdoor])
            XCTAssertEqual(segments.first?.coordinates, reversed ? expected.reversed() : expected)
        }
    }

    func testEntranceSharesThresholdInBothDirections() {
        let outside = F.edge("e", "a", "b", coordinates: [[0, 1], [0.4, 0]])
        let door = F.entrance("door", "b", "c")
        let inside = F.edge("f", "c", "d", kind: .walkingPath(location: F.first, pathKind: "corridor"),
                            coordinates: [[0.6, 0], [1, 1]])
        let threshold = coordinate(0.5, 0)
        for reversed in [false, true] {
            let edges = reversed ? [inside, door, outside] : [outside, door, inside]
            let segments = RoutePolylineBuilder.buildSegments(from: path(edges.map { .init(edge: $0, isReversed: reversed) }))
            XCTAssertEqual(segments.map(\.scope), reversed ? [indoor, .outdoor] : [.outdoor, indoor])
            XCTAssertEqual(segments.first?.coordinates.last, threshold)
            XCTAssertEqual(segments.last?.coordinates.first, threshold)
            XCTAssertEqual(segments.first?.coordinates.first, reversed ? coordinate(1) : coordinate(0))
            XCTAssertEqual(segments.last?.coordinates.last, reversed ? coordinate(0) : coordinate(1))
        }
    }

    func testSingleEntranceUsesTheActualNodesOnBothSides() {
        let door = F.entrance("door", "a", "b")
        let endpoints = ["a": coordinate(1), "b": coordinate(2)]
        for reversed in [false, true] {
            let step = RouteStep(edge: door, isReversed: reversed)
            let segments = RoutePolylineBuilder.buildSegments(from: path([step]), nodeCoordinates: endpoints)
            XCTAssertEqual(segments.map(\.scope), reversed ? [indoor, .outdoor] : [.outdoor, indoor])
            XCTAssertEqual(segments.map(\.coordinates), [
                [reversed ? coordinate(2) : coordinate(1), coordinate(0.5, 0)],
                [coordinate(0.5, 0), reversed ? coordinate(1) : coordinate(2)]
            ])
        }
    }

    func testTransitionWithoutGeometryBreaksTheLineEvenWithinTheSameScope() {
        let edges = [F.edge("e", "a", "b", coordinates: [[0, 1], [1, 1]]),
                     F.edge("t", "b", "c", kind: .transition(label: "階段"), coordinates: []),
                     F.edge("f", "c", "d", coordinates: [[5, 1], [6, 1]])]
        let segments = RoutePolylineBuilder.buildSegments(from: path(edges.map { .init(edge: $0, isReversed: false) }))
        XCTAssertEqual(segments.map(\.coordinates), [[coordinate(0), coordinate(1)], [coordinate(5), coordinate(6)]])
        XCTAssertNotEqual(segments.first?.id, segments.last?.id)
    }

    func testEmptyPathsAndInvalidPositions() {
        XCTAssertEqual(RoutePolylineBuilder.buildSegments(from: path([])), [])
        let edge = F.edge("e", "a", "b", coordinates: [[], [0], [1, 2, 3], [.infinity, 1], [1, .nan], [3, 4]])
        let result = RoutePolylineBuilder.buildSegments(from: path([.init(edge: edge, isReversed: false)]))
        XCTAssertEqual(result.first?.coordinates, [coordinate(1, 2), coordinate(3, 4)])
        let single = F.edge("s", "a", "b", coordinates: [[1, 2], [1, 2]])
        XCTAssertEqual(RoutePolylineBuilder.buildSegments(from: path([.init(edge: single, isReversed: false)])), [])
    }

    func testDistanceFormattingBoundaries() {
        let cases: [(Double, String)] = [(0, "0 m"), (-0.0, "0 m"), (0.4, "1 m"), (57.7, "58 m"),
            (999.4, "999 m"), (999.5, "1.0 km"), (1000, "1.0 km"), (1240, "1.2 km"), (1250, "1.3 km"),
            (-1, "—"), (.nan, "—"), (.infinity, "—")]
        for (meters, expected) in cases {
            XCTAssertEqual(RouteSummaryFormatter.formatDistance(meters: meters), expected, "\(meters) m")
        }
    }

    func testWalkingDurationFormattingBoundaries() {
        let cases: [(Double, String)] = [(0, "0分"), (15, "1分未満"), (53, "1分未満"), (60, "約1分"),
            (89, "約1分"), (90, "約2分"), (3569, "約59分"), (3570, "約1時間"), (3599, "約1時間"),
            (3600, "約1時間"), (3900, "約1時間5分"), (7199, "約2時間"),
            (-1, "—"), (.nan, "—"), (.infinity, "—")]
        for (seconds, expected) in cases {
            XCTAssertEqual(RouteSummaryFormatter.formatWalkingDuration(seconds: seconds), expected, "\(seconds) s")
        }
    }

    func testSummaryAndAnnouncementsUsePublishedCostsRegardlessOfGeometry() {
        let route = route(points: [coordinate(0), coordinate(30)])
        XCTAssertEqual(route.totalDistanceMeters, 57.7)
        XCTAssertEqual(route.totalEstimatedSeconds, 53)
        XCTAssertEqual(RouteAccessibilityText.distance(route), "距離、58 m")
        XCTAssertEqual(RouteAccessibilityText.walkingDuration(route), "徒歩の目安、1分未満")
        XCTAssertEqual(RouteAccessibilityText.marker(route.origin, isOrigin: true), "出発地、a")
        XCTAssertEqual(RouteAccessibilityText.marker(route.destination, isOrigin: false), "目的地、格納庫")
        XCTAssertEqual(RouteAccessibilityText.started(route), "格納庫への案内を開始しました。徒歩の目安、1分未満、距離、58 m。")
        XCTAssertEqual(RouteAccessibilityText.ended, "経路案内を終了しました。")
    }

    func testRouteCameraContainsEndpointsAndBendsWithSpaceAboveAndBelow() throws {
        let start = coordinate(-1, 2), end = coordinate(1, 4)
        let points = [coordinate(-3, 3), coordinate(2, 6)]
        let region = try XCTUnwrap(CampusMapRouteCamera.region(for: route(points: points, start: start, end: end)))
        let top = region.center.latitude + region.latitudeDelta / 2
        let bottom = region.center.latitude - region.latitudeDelta / 2
        for point in points + [start, end] {
            XCTAssertTrue((bottom...top).contains(point.latitude))
            XCTAssertLessThan(abs(point.longitude - region.center.longitude), region.longitudeDelta / 2)
        }
        XCTAssertLessThan(region.center.latitude, 4)
        XCTAssertGreaterThan(top, 6)
        XCTAssertGreaterThan(2 - bottom, top - 6)
        XCTAssertNil(CampusMapRouteCamera.region(for: route(points: [])))
        let single = try XCTUnwrap(CampusMapRouteCamera.region(for: route(points: [], start: start)))
        XCTAssertEqual(single.latitudeDelta, 0.0012)
        XCTAssertEqual(single.longitudeDelta, 0.0012)
    }

    func testAccessibilityRouteCameraReservesMoreSpaceAboveMarkers() throws {
        let route = route(points: [coordinate(-3, 3), coordinate(2, 6)])
        let standard = try XCTUnwrap(CampusMapRouteCamera.region(for: route))
        let accessibility = try XCTUnwrap(CampusMapRouteCamera.region(for: route, reservesSpaceAboveMarkers: true))
        XCTAssertGreaterThan(
            accessibility.center.latitude + accessibility.latitudeDelta / 2,
            standard.center.latitude + standard.latitudeDelta / 2
        )
        XCTAssertLessThan(accessibility.center.latitude - accessibility.latitudeDelta / 2, 3)
    }

    func testFailuresExplainTheirCauseAndDoNotOfferStraightLineGuidance() {
        let id = CanonicalSpotID(rawValue: "sab")
        let failures: [RouteFailurePresentation] = [
            .disconnected(destinationID: id, destinationName: "技能審査棟"), .unreachable(destinationID: id, destinationName: nil),
            .notRoutable(.missingAccessNode, destinationID: id, destinationName: nil), .unknownOrigin("原点"),
            .originNotRoutable(.ambiguousPrimaryEntrance)
        ]
        XCTAssertEqual(Set(failures.map(\.title)).count, failures.count)
        for failure in failures {
            XCTAssertFalse(failure.systemImageName.isEmpty)
            XCTAssertEqual(RouteAccessibilityText.announcement(for: .routeFailure(failure)), "\(failure.title)。\(failure.detail)")
        }
        XCTAssertTrue(failures[0].detail.contains("技能審査棟"))
        XCTAssertTrue(failures[1].detail.contains("sab"))
        XCTAssertTrue(failures[0...1].allSatisfy { $0.detail.contains("直線での案内は行いません") })
        XCTAssertTrue(failures[4].detail.contains("代表入口が複数"))
    }
}
