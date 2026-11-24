import XCTest
@testable import Nexus

@MainActor
final class BundleRouteSolverTests: XCTestCase {
    private let gateID = CanonicalSpotID(rawValue: "campus_lm_001")
    private let roomID = CanonicalSpotID(rawValue: "mb_1f_cl_001")

    private func exampleData() throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../", isDirectory: true).standardizedFileURL
        return try Data(contentsOf: root.appendingPathComponent("docs/schemas/examples/participant-bundle-v2.example.json"))
    }

    func testPublishedSampleUsesAccessNodesFloorNamesAndEngineSteps() throws {
        let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: exampleData())
        let requestID = UUID()
        let outcome = BundleRouteSolver.resolve(in: bundle, origin: .destination(gateID), destinationSpotID: roomID,
                                                requestedFrom: .guide, requestID: requestID)
        guard case .accepted(let destination) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(destination.canonicalSpotID, roomID)
        XCTAssertEqual(destination.requestedFrom, .guide)
        let route = try XCTUnwrap(destination.resolvedRoute)
        XCTAssertEqual(route.requestID, requestID)
        XCTAssertEqual(route.bundleVersion, 42)
        XCTAssertEqual(route.totalDistanceMeters, 57.7, accuracy: 1e-9)
        XCTAssertEqual(route.totalEstimatedSeconds, 53)
        XCTAssertEqual(route.path.steps.count, 4)
        XCTAssertTrue(route.hasIndoorSteps)
        XCTAssertEqual(route.traversedFloorLabels, ["教室棟 1F"])
        XCTAssertEqual(route.segments.map(\.scope), [.outdoor, .indoor(buildingID: "mb", floorID: "mb_1f")])
        XCTAssertEqual(route.origin, .init(id: gateID.rawValue, displayName: "航空神社",
                                          coordinate: .init(latitude: 42.7716, longitude: 141.6806)))
        XCTAssertEqual(route.destination, .init(id: roomID.rawValue, displayName: "電気装備教室",
                                               coordinate: .init(latitude: 42.7714, longitude: 141.6812)))
        assertOutdoorStepsToEntrance(route)
        XCTAssertEqual(route.segments.first?.coordinates.first, route.origin.coordinate)
        XCTAssertEqual(route.segments.last?.coordinates.last, route.destination.coordinate)
        XCTAssertEqual(route.segments[0].coordinates.last, route.segments[1].coordinates.first)
    }

    private func assertOutdoorStepsToEntrance(_ route: ResolvedRoute, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(route.outdoorSteps.map(\.kind), [.depart(fromIndoor: false), .turn(.left), .arrive(continuesIndoors: true)],
                       file: file, line: line)
        XCTAssertEqual(route.outdoorSteps.compactMap(\.distanceMeters), [27.4, 16.4], file: file, line: line)
        XCTAssertEqual(route.outdoorSteps.last?.nodeID, "campus_n_021", file: file, line: line)
        XCTAssertEqual(route.outdoorSteps.last?.titleText, "教室棟 正面入口に到着（以降は屋内）", file: file, line: line)
    }

    func testOutdoorBuildingRouteUsesTheJunctionAndEndsAtThePublishedEntrance() throws {
        let outcome = BundleRouteSolver.resolve(in: RouteCheckFixtures.bundle, origin: .destination(gateID),
            destinationSpotID: .init(rawValue: "mb"), requestedFrom: .map)
        guard case .accepted(let destination) = outcome else { return XCTFail("\(outcome)") }
        let steps = try XCTUnwrap(destination.resolvedRoute).outdoorSteps
        XCTAssertEqual(steps.map(\.kind), [.depart(fromIndoor: false), .turn(.left), .arrive(continuesIndoors: false)])
        let turn = try XCTUnwrap(steps.first { $0.vertexSource == .edgeJunction })
        XCTAssertEqual(turn.nodeID, "campus_n_020")
        XCTAssertEqual(try XCTUnwrap(turn.turnAngleDegrees), -53.71876, accuracy: 0.0001)
        XCTAssertEqual(steps.compactMap(\.distanceMeters), [27.4, 16.4])
        XCTAssertEqual(steps.last?.titleText, "教室棟に到着")
        XCTAssertEqual(steps.last?.landmarkNoteText, "目印：教室棟 正面入口")
    }

    func testSamePointAndAccessibleOnlyOnPublishedSample() throws {
        let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: exampleData())
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: .destination(gateID), destinationSpotID: gateID,
                                                 requestedFrom: .map),
                       .samePoint(.init(destinationSpotID: gateID, displayName: "航空神社", nodeID: "campus_n_030")))
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: .destination(gateID), destinationSpotID: roomID,
                                                 requestedFrom: .map, options: .init(accessibilityPolicy: .accessibleOnly)),
                       .routeFailure(.unreachable(destinationID: roomID, destinationName: "電気装備教室")))
    }

    func testUnknownDestinationsAndOriginsAreNotSubstituted() throws {
        let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: exampleData())
        for rawID in ["absent", "MB_1F_CL_001", "campus_n_030"] {
            let id = CanonicalSpotID(rawValue: rawID)
            XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: id, requestedFrom: .home),
                           .unknownSpot(id))
        }
        for origin in [RouteOrigin.node(id: "absent"), .destination(.init(rawValue: "absent"))] {
            XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: origin, destinationSpotID: roomID, requestedFrom: .map),
                           .routeFailure(.unknownOrigin("absent")))
        }
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: roomID, requestedFrom: .map),
                       .unavailable(RouteStateMessages.originRequired))
    }

    func testMissingMapAndEdgelessMapTakePrecedenceOverMissingOrigin() throws {
        let objects = [BundleFixtures.bundleObject(map: NSNull()), BundleFixtures.bundleObject()]
        for object in objects {
            let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: BundleFixtures.data(object))
            XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: gateID, requestedFrom: .map),
                           .unavailable(RouteStateMessages.networkUnavailable))
        }
    }

    private func exampleChangingFeatures(_ edit: (inout [[String: Any]]) throws -> Void) throws -> ParticipantBundle {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: exampleData()) as? [String: Any])
        var map = try XCTUnwrap(object["map"] as? [String: Any])
        var geo = try XCTUnwrap(map["geojson"] as? [String: Any])
        var features = try XCTUnwrap(geo["features"] as? [[String: Any]])
        try edit(&features)
        geo["features"] = features
        map["geojson"] = geo
        object["map"] = map
        return try JSONDecoder().decode(ParticipantBundle.self, from: BundleFixtures.data(object))
    }

    func testInvalidAccessNodeDistinguishesDestinationAndOrigin() throws {
        let bundle = try exampleChangingFeatures { features in
            let index = try XCTUnwrap(features.firstIndex { $0["id"] as? String == roomID.rawValue })
            var properties = try XCTUnwrap(features[index]["properties"] as? [String: Any])
            properties["access_node_id"] = "campus_n_030"
            features[index]["properties"] = properties
        }
        let reason = RouteFailureReason.NotRoutable.invalidAccessNode("campus_n_030")
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: roomID, requestedFrom: .map),
                       .routeFailure(.notRoutable(reason, destinationID: roomID, destinationName: "電気装備教室")))
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: .destination(roomID), destinationSpotID: gateID, requestedFrom: .map),
                       .routeFailure(.originNotRoutable(reason)))
    }

    func testAmbiguousPrimaryEntranceAndSpotWithoutDestinationFeature() throws {
        let bundle = try exampleChangingFeatures { features in
            var second = try XCTUnwrap(features.first { $0["id"] as? String == "mb_ent_001" })
            second["id"] = "mb_ent_002"
            features.append(second)
            features.removeAll { $0["id"] as? String == roomID.rawValue }
        }
        let building = CanonicalSpotID(rawValue: "mb")
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: building, requestedFrom: .map),
                       .routeFailure(.notRoutable(.ambiguousPrimaryEntrance, destinationID: building, destinationName: "教室棟")))
        XCTAssertEqual(BundleRouteSolver.resolve(in: bundle, origin: nil, destinationSpotID: roomID, requestedFrom: .map),
                       .unknownSpot(roomID))
    }

    func testPreviewUsesThePublishedMainGateWhenNoOtherOriginIsAvailable() async throws {
        let example = String(decoding: try exampleData(), as: UTF8.self)
        let withMainGate = example.replacingOccurrences(of: "campus_n_030", with: "campus_n_001")
        let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: Data(withMainGate.utf8))
        let snapshot = PublishedBundleSnapshot(
            stored: .init(bundle: bundle, metadata: RouteCheckFixtures.snapshot.stored.metadata),
            isConfirmedLatest: true, lastConfirmedAt: nil
        )
        let handler = RouteRequestHandling.bundle(source: .fixed(snapshot))

        let preview = await handler.preview(fix: nil, manualOrigin: nil, destination: roomID, from: .home)
        let route = try XCTUnwrap(preview.destination?.resolvedRoute)
        XCTAssertEqual(route.origin.id, "campus_n_001")
        XCTAssertEqual(route.origin.label, "正門")
        XCTAssertEqual(route.totalDistanceMeters, 57.7, accuracy: 1e-9)
    }

    func testMissingSnapshotAndReadFailureReportDataUnavailable() async {
        for source in [PublishedBundleSource.fixed(nil), .init(current: { throw TestStubError.simulated })] {
            let outcome = await RouteRequestHandling.bundle(source: source).requestRoute(roomID, .home)
            XCTAssertEqual(outcome, .unavailable(RouteStateMessages.dataUnavailable))
        }
    }

    func testReturnFromDetailDiscardsPendingLoadAndKeepsSnapshot() async {
        let gate = TestGate()
        let store = MapStore(client: .stub(spotDetail: { id in
            await gate.wait()
            return .unknownSpot(id)
        }), snapshotBoundary: .init(advance: { true }))
        let loading = Task { await store.selectOnMap(roomID) }
        await gate.waitUntilWaiting()
        store.dismissDetailForRoute()
        await gate.open()
        await loading.value
        XCTAssertEqual(store.contentRevision, 0)
        XCTAssertNil(store.selection)
        XCTAssertEqual(store.detailState, .none)
    }

    func testEndingGuidanceAlsoInvalidatesPendingAcceptance() async {
        let gate = TestGate()
        let store = RouteRequestStore(handler: RouteRequestHandling { id, tab in
            await gate.wait()
            return .accepted(.init(canonicalSpotID: id, requestedFrom: tab))
        })
        let loading = Task { await store.requestRoute(to: roomID, from: .map) }
        await gate.waitUntilWaiting()
        store.endGuidance()
        await gate.open()
        await loading.value
        XCTAssertNil(store.activeDestination)
        XCTAssertNil(store.lastOutcome)
        XCTAssertFalse(store.isRequesting)
    }

    func testReopeningMapKeepsItsVersionUntilGuidanceEnds() async {
        let model = AppShellModel(searchClient: .unconfigured, mapContentClient: .unconfigured,
                                  mapSnapshotBoundary: .init(advance: { true }), mapSurface: .unavailable,
                                  guidanceClient: .unconfigured, routeHandler: RouteCheckFixtures.routeHandler(for: .indoor))
        await model.routeStore.requestRoute(to: roomID, from: .home)
        XCTAssertNotNil(model.routeStore.activeRoute)
        await model.selectedTabChanged(from: .home, to: .map)
        XCTAssertEqual(model.mapStore.contentRevision, 0)
        model.routeStore.endGuidance()
        await model.selectedTabChanged(from: .home, to: .map)
        XCTAssertEqual(model.mapStore.contentRevision, 1)
    }

    func testDebugLaunchArgumentsAndEveryScenarioUseTheBundleSolver() async throws {
        typealias F = RouteCheckFixtures
        XCTAssertNil(F.scenario(arguments: []))
        XCTAssertEqual(F.scenario(arguments: ["-NexusRouteCheck"]), .found)
        XCTAssertEqual(F.scenario(arguments: ["-NexusRouteCheck", "-NexusLocationFixture"]), .found)
        for scenario in F.Scenario.allCases {
            XCTAssertEqual(F.scenario(arguments: ["-NexusRouteCheck", scenario.rawValue]), scenario)
            let id = scenario.destination
            let outcome = await F.routeHandler(for: scenario).requestRoute(id, .map)
            switch scenario {
            case .found, .indoor:
                guard case .accepted(let destination) = outcome else { return XCTFail("\(outcome)") }
                let route = try XCTUnwrap(destination.resolvedRoute)
                XCTAssertEqual(route.destination.id, id.rawValue)
                if scenario == .indoor {
                    XCTAssertEqual(route.totalDistanceMeters, 57.7, accuracy: 1e-9)
                    assertOutdoorStepsToEntrance(route)
                    XCTAssertEqual(route.totalEstimatedSeconds, 53)
                    XCTAssertEqual(route.traversedFloorLabels, ["教室棟 1F"])
                } else {
                    XCTAssertEqual(route.segments.map(\.scope), [.outdoor])
                    XCTAssertGreaterThan(route.allCoordinates.count, 2)
                    let steps = route.outdoorSteps
                    XCTAssertEqual(steps.map(\.kind), [.depart(fromIndoor: false), .turn(.right), .turn(.left),
                                                      .arrive(continuesIndoors: false)])
                    XCTAssertEqual(steps.compactMap(\.distanceMeters).reduce(0, +), 228, accuracy: 1e-9)
                    let angles = steps.compactMap(\.turnAngleDegrees)
                    XCTAssertEqual(try XCTUnwrap(angles.first), 47.75467, accuracy: 0.0001)
                    XCTAssertEqual(try XCTUnwrap(angles.last), -90, accuracy: 0.0001)
                }
            case .samePoint:
                XCTAssertEqual(outcome, .samePoint(.init(destinationSpotID: id, displayName: "正門付近（検証用）", nodeID: "campus_n_030")))
            case .disconnected: XCTAssertEqual(outcome, .routeFailure(.disconnected(destinationID: id, destinationName: "技能審査棟")))
            case .unreachable: XCTAssertEqual(outcome, .routeFailure(.unreachable(destinationID: id, destinationName: "格納庫B")))
            case .notRoutable: XCTAssertEqual(outcome, .routeFailure(.notRoutable(.missingAccessNode, destinationID: id, destinationName: "実習棟")))
            case .unknown: XCTAssertEqual(outcome, .unknownSpot(id))
            case .unavailable: XCTAssertEqual(outcome, .unavailable(RouteStateMessages.dataUnavailable))
            }
        }
    }

    func testExplicitOriginOverridesDefaultAndBrowsingOrFailureKeepsActiveRoute() async throws {
        let store = RouteRequestStore(handler: RouteCheckFixtures.routeHandler(for: .found))
        await store.requestRoute(from: .node(id: "campus_n_020", displayName: "分岐点"), to: roomID, from: .home)
        let destination = try XCTUnwrap(store.activeDestination)
        let route = try XCTUnwrap(store.activeRoute)
        XCTAssertEqual(route.origin.id, "campus_n_020")
        XCTAssertEqual(route.origin.displayName, "分岐点")
        XCTAssertEqual(destination.requestedFrom, .home)
        let map = MapStore(client: .bundle(source: RouteCheckFixtures.source))
        await map.selectOnMap(gateID)
        let context = map.surfaceContext(activeRoute: store.activeRoute, routeCameraFitRevision: 3)
        XCTAssertEqual(context.focusedSpotID, gateID)
        XCTAssertEqual(context.activeRoute, route)
        XCTAssertEqual(context.routeCameraFitRevision, 3)
        for id in [RouteCheckFixtures.Scenario.disconnected.destination, gateID] {
            await store.requestRoute(to: id, from: .map)
            XCTAssertEqual(store.activeDestination, destination)
            XCTAssertEqual(store.activeRoute, route)
        }
        store.endGuidance()
        XCTAssertNil(store.activeRoute)
        XCTAssertNil(store.activeDestination)
        XCTAssertNil(store.lastOutcome)
    }
}
