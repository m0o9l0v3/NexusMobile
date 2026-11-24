import XCTest
@testable import Nexus

@MainActor
final class RoutePreviewTests: XCTestCase {
    private let room = RoutePreviewTarget(id: .init(rawValue: "mb_1f_cl_001"), displayName: "電気装備教室")

    func testHomePreviewStartsTheSameRouteOnlyAfterConfirmation() async throws {
        let harness = TestHarness(routeHandler: RouteCheckFixtures.routeHandler(for: .indoor))
        await harness.handle(.allEvents, from: .home)

        await harness.handle(.routePreview(room), from: .home)
        let session = try XCTUnwrap(harness.routeStore.previewSession)
        XCTAssertEqual(session.target, room)
        XCTAssertNil(harness.routeStore.previewResult)
        harness.coordinator.startPreviewedRoute(id: session.id)
        XCTAssertEqual(harness.router.selectedTab, .home)

        await harness.routeStore.loadPreview(id: session.id, currentFix: nil, manualOrigin: nil)
        let preview = try XCTUnwrap(harness.routeStore.previewResult)
        let route = try XCTUnwrap(preview.destination?.resolvedRoute)
        XCTAssertEqual(preview.target?.locationText, "教室棟・1F")
        XCTAssertEqual(route.totalDistanceMeters, 57.7, accuracy: 1e-9)
        XCTAssertEqual(route.totalEstimatedSeconds, 53)
        XCTAssertFalse(route.outdoorSteps.isEmpty)
        XCTAssertEqual(harness.router.selectedTab, .home)
        XCTAssertNil(harness.routeStore.activeRoute)
        XCTAssertNil(harness.routeStore.lastOutcome)

        harness.coordinator.startPreviewedRoute(id: session.id)
        XCTAssertEqual(harness.router.selectedTab, .map)
        XCTAssertEqual(harness.router.homePath, [.allEvents])
        XCTAssertNil(harness.routeStore.previewSession)
        XCTAssertEqual(harness.routeStore.activeRoute, route)
    }

    func testClosingPreviewKeepsTheTabAndActiveRoute() async throws {
        let harness = TestHarness(routeHandler: RouteCheckFixtures.routeHandler(for: .found))
        await harness.handle(.route(destinationSpotID: RouteCheckFixtures.Scenario.found.destination), from: .home)
        let active = try XCTUnwrap(harness.routeStore.activeRoute)
        await harness.handle(.routePreview(room), from: .home)
        let session = try XCTUnwrap(harness.routeStore.previewSession)
        await harness.routeStore.loadPreview(id: session.id, currentFix: nil, manualOrigin: nil)
        XCTAssertNotNil(harness.routeStore.previewResult?.destination)

        harness.routeStore.dismissPreview()
        harness.coordinator.startPreviewedRoute(id: session.id)

        XCTAssertNil(harness.routeStore.previewSession)
        XCTAssertNil(harness.routeStore.previewResult)
        XCTAssertEqual(harness.router.selectedTab, .home)
        XCTAssertEqual(harness.routeStore.activeRoute, active)
    }

    func testAnotherRequestCannotReplaceTheCurrentPreviewWhenItFinishesLate() async throws {
        let gate = TestGate()
        let harness = TestHarness(routeHandler: RouteRequestHandling { _, _ in
            await gate.wait()
            return .unavailable(RouteStateMessages.previewFailed)
        })
        await harness.handle(.routePreview(room), from: .home)
        let first = try XCTUnwrap(harness.routeStore.previewSession)
        let task = Task {
            await harness.routeStore.loadPreview(id: first.id, currentFix: nil, manualOrigin: nil)
        }
        await gate.waitUntilWaiting()

        harness.routeStore.dismissPreview()
        let other = RoutePreviewTarget(id: .init(rawValue: "hgr_a"), displayName: "格納庫A")
        await harness.handle(.routePreview(other), from: .home)
        await gate.open()
        await task.value

        XCTAssertEqual(harness.routeStore.previewSession?.target, other)
        XCTAssertNil(harness.routeStore.previewResult)
        XCTAssertNil(harness.routeStore.activeRoute)
    }

    func testUnavailableDisconnectedAndLoadFailureCannotStartGuidance() async throws {
        let disconnectedID = RouteCheckFixtures.Scenario.disconnected.destination
        let cases: [(RouteRequestHandling, CanonicalSpotID, RouteRequestOutcome)] = [
            (.unconfigured, room.id, await RouteRequestHandling.unconfigured.resolve(destination: room.id, from: .home)),
            (.bundle(source: .fixed(nil)), room.id, .unavailable(RouteStateMessages.dataUnavailable)),
            (.bundle(source: .init(current: { throw PublishedBundleSourceError.notAvailable })),
             room.id, .unavailable(RouteStateMessages.previewFailed)),
            (RouteCheckFixtures.routeHandler(for: .disconnected), disconnectedID,
             .routeFailure(.disconnected(destinationID: disconnectedID, destinationName: "技能審査棟")))
        ]
        for (handler, id, expected) in cases {
            let harness = TestHarness(routeHandler: handler)
            await harness.handle(.routePreview(.init(id: id, displayName: "目的地")), from: .home)
            let session = try XCTUnwrap(harness.routeStore.previewSession)
            await harness.routeStore.loadPreview(id: session.id, currentFix: nil, manualOrigin: nil)
            let result = try XCTUnwrap(harness.routeStore.previewResult)
            XCTAssertEqual(result.outcome, expected)
            XCTAssertEqual(result.statusMessage, expected.statusMessage)
            XCTAssertNil(result.destination)
            XCTAssertTrue(result.buildings.isEmpty)

            harness.coordinator.startPreviewedRoute(id: session.id)
            XCTAssertEqual(harness.routeStore.previewSession?.id, session.id)
            XCTAssertNil(harness.routeStore.activeRoute)
            XCTAssertEqual(harness.router.selectedTab, .home)
        }
    }

    func testNearbyOutdoorNodeTakesPriorityAndDistantFixUsesManualOrigin() async throws {
        let handler = RouteCheckFixtures.routeHandler(for: .indoor)
        let fix = LocationFix(coordinate: .init(latitude: 42.7714, longitude: 141.6808),
                              horizontalAccuracy: 8, timestamp: .now)
        let distant = LocationFix(coordinate: .init(latitude: 43, longitude: 141), horizontalAccuracy: 8, timestamp: .now)
        let manual = RouteOrigin.node(id: "campus_n_021", displayName: "教室棟入口付近")

        let nearby = await handler.preview(fix: fix, manualOrigin: manual, destination: room.id, from: .map)
        XCTAssertEqual(nearby.destination?.resolvedRoute?.origin.id, "campus_n_020")
        XCTAssertEqual(nearby.destination?.resolvedRoute?.origin.label, "現在地付近")

        let fallback = await handler.preview(fix: distant, manualOrigin: manual, destination: room.id, from: .map)
        XCTAssertEqual(fallback.destination?.resolvedRoute?.origin.id, "campus_n_021")

        let noPublishedGate = await RouteRequestHandling.bundle(source: RouteCheckFixtures.source)
            .preview(fix: distant, manualOrigin: nil, destination: room.id, from: .home)
        XCTAssertEqual(noPublishedGate.outcome, .unavailable(RouteStateMessages.originRequired))
    }

    func testOfflinePreviewKeepsItsBundleVersionAndSavedMetadataWhenStarted() async throws {
        let snapshot = PublishedBundleSnapshot(stored: RouteCheckFixtures.snapshot.stored,
                                               isConfirmedLatest: false, lastConfirmedAt: nil)
        let handler = RouteRequestHandling.bundle(source: .fixed(snapshot), defaultOrigin: RouteCheckFixtures.defaultOrigin)
        let harness = TestHarness(routeHandler: handler)
        await harness.handle(.routePreview(room), from: .home)
        let session = try XCTUnwrap(harness.routeStore.previewSession)
        await harness.routeStore.loadPreview(id: session.id, currentFix: nil, manualOrigin: nil)

        let result = try XCTUnwrap(harness.routeStore.previewResult)
        XCTAssertEqual(result.savedMetadata?.bundleVersion, 42)
        XCTAssertFalse(result.buildings.isEmpty)
        harness.coordinator.startPreviewedRoute(id: session.id)
        XCTAssertEqual(harness.routeStore.activeRoute?.bundleVersion, 42)
        XCTAssertEqual(harness.routeStore.activeDestination?.savedMetadata, result.savedMetadata)
    }
}
