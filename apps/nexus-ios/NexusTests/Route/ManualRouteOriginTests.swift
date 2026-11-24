import XCTest
@testable import Nexus

@MainActor
final class ManualRouteOriginTests: XCTestCase {
    private let hangar = CanonicalSpotID(rawValue: "hgr_a")
    private let gate = CanonicalSpotID(rawValue: "campus_lm_001")

    private func model(source: PublishedBundleSource = RouteCheckFixtures.source,
                       boundary: MapSnapshotBoundary = .none,
                       services: LocationServices? = nil) -> AppShellModel {
        AppShellModel(searchClient: .unconfigured, mapContentClient: .bundle(source: source),
                      mapSnapshotBoundary: boundary, mapSurface: .unavailable, guidanceClient: .unconfigured,
                      routeHandler: .bundle(source: source), routeOriginClient: .bundle(source: source),
                      locationServices: services ?? CurrentLocationFixture.denied.services)
    }

    private func options(_ store: ManualRouteOriginStore) throws -> ManualRouteOriginSnapshot {
        guard case .loaded(let snapshot) = store.session?.state else { throw TestStubError.simulated }
        return snapshot
    }

    private func choose(_ id: CanonicalSpotID, in model: AppShellModel) async throws {
        let snapshot = try options(model.routeOriginStore)
        let option = try XCTUnwrap(snapshot.options.first { $0.id == id })
        await model.routeOriginStore.selectOrigin(option)
    }

    func testCatalogUsesPublishedOrderAndOnlyOutdoorEndpoints() async throws {
        let model = model()
        await model.routeOriginStore.beginSelection(for: hangar, from: .guide)
        let snapshot = try options(model.routeOriginStore)
        XCTAssertEqual(snapshot.options.map(\.id.rawValue), ["campus_lm_001", "hgr_a", "hgr_b", "mb", "mb_ent_001", "sab"])
        XCTAssertEqual(snapshot.options.map(\.outdoorNodeID),
                       ["campus_n_030", "campus_n_031", "campus_n_032", "campus_n_021", "campus_n_021", "campus_n_033"])
        XCTAssertEqual(snapshot.destination?.canonicalSpotID, hangar)
        XCTAssertEqual(snapshot.bundleVersion, 42)
        XCTAssertNil(snapshot.savedMetadata)

        try await choose(.init(rawValue: "sab"), in: model)
        XCTAssertEqual(model.routeStore.lastOutcome, .routeFailure(.disconnected(destinationID: hangar, destinationName: "格納庫A")))
        XCTAssertNil(model.routeStore.activeRoute)
        XCTAssertEqual(model.routeStore.lastAttemptedTab, .guide)
        await model.routeOriginStore.beginOriginRetryForLastAttempt()
        XCTAssertEqual(model.routeOriginStore.session?.destinationSpotID, hangar)
        try await choose(gate, in: model)
        XCTAssertEqual(model.routeOriginStore.selectedOrigin, .destination(gate))
        XCTAssertEqual(model.routeStore.activeDestination?.requestedFrom, .guide)
        XCTAssertEqual(model.routeStore.activeRoute?.destination.id, hangar.rawValue)
    }

    func testRetryShowsActiveOriginOnlyForTheActiveDestination() async throws {
        let model = model()
        let otherHangar = CanonicalSpotID(rawValue: "hgr_b")
        let disconnected = CanonicalSpotID(rawValue: "sab")
        await model.routeStore.requestRoute(from: .destination(gate), to: hangar, from: .map)
        XCTAssertEqual(model.routeStore.activeRoute?.origin.id, gate.rawValue)

        for (destination, name) in [(otherHangar, "格納庫B"), (hangar, "格納庫A")] {
            await model.routeOriginStore.beginSelection(for: destination, from: .map)
            try await choose(disconnected, in: model)
            XCTAssertEqual(model.routeStore.lastOutcome, .routeFailure(.disconnected(destinationID: destination, destinationName: name)))
            await model.routeOriginStore.beginOriginRetryForLastAttempt()
            let session = try XCTUnwrap(model.routeOriginStore.session)
            XCTAssertEqual(session.destinationSpotID, destination)
            XCTAssertEqual(session.currentOriginSpotID, destination == hangar ? gate : nil)
            model.routeOriginStore.cancelSelection()
        }
    }

    func testIsConfiguredReflectsManualRouteOriginClient() {
        let routeStore = RouteRequestStore(handler: .unconfigured)
        XCTAssertFalse(ManualRouteOriginStore(client: .unconfigured, routeStore: routeStore).isConfigured)
        XCTAssertTrue(ManualRouteOriginStore(client: .bundle(source: RouteCheckFixtures.source), routeStore: routeStore).isConfigured)
    }

    func testUnavailableDestinationUsesRouteNoticeAndExactID() async throws {
        let model = model()
        await model.routeStore.requestRoute(from: .destination(gate), to: hangar, from: .map)
        let previous = try XCTUnwrap(model.routeStore.activeDestination)
        let unknown = CanonicalSpotID(rawValue: "HGR_A")
        let noEntrance = CanonicalSpotID(rawValue: "ptb")
        for (id, expected) in [(unknown, RouteRequestOutcome.unknownSpot(unknown)),
                               (noEntrance, .routeFailure(.notRoutable(.missingAccessNode, destinationID: noEntrance, destinationName: "実習棟")))] {
            XCTAssertEqual(ManualRouteOriginCatalog.load(in: RouteCheckFixtures.snapshot, for: id), .destinationUnavailable(expected))
            await model.routeOriginStore.beginSelection(for: id, from: .home)
            XCTAssertNil(model.routeOriginStore.session)
            XCTAssertEqual(model.routeStore.lastOutcome, expected)
            XCTAssertEqual(model.routeStore.lastAttemptedDestination, id)
            XCTAssertEqual(model.routeStore.activeDestination, previous)
        }
    }

    func testEmptyListKeepsGraphOnlyDestinationAndSavedVersion() async throws {
        let snapshot = try versionedSnapshot(1, withSpots: false)
        let model = model(source: .fixed(snapshot))
        let id = CanonicalSpotID(rawValue: "Mb")
        await model.routeOriginStore.beginSelection(for: id, from: .map)
        guard case let .empty(destination, actualID, version, metadata, message) = model.routeOriginStore.session?.state else {
            return XCTFail("候補0件を表示する")
        }
        XCTAssertNil(destination)
        XCTAssertEqual(actualID, id)
        XCTAssertEqual(version, 1)
        XCTAssertEqual(metadata?.bundleVersion, 1)
        XCTAssertFalse(message.title.isEmpty)
        XCTAssertNil(model.routeStore.lastOutcome)
    }

    func testPinKeepsOptionsAndSolverOnSameVersionUntilNextVisitAfterCancelOrEnd() async throws {
        let first = try versionedSnapshot(1)
        let second = try versionedSnapshot(2)
        let destination = CanonicalSpotID(rawValue: "Mb")
        for cancel in [false, true] {
            let upstream = MutableUpstream(first)
            let pin = PinnedBundleSource(upstream: upstream.source)
            let model = model(source: pin.source, boundary: .pinned(pin))
            await model.mapStore.selectOnMap(destination)
            await model.routeOriginStore.beginSelection(for: destination, from: .home)
            await upstream.set(second)
            await model.selectedTabChanged(from: .home, to: .map)
            let snapshot = try options(model.routeOriginStore)
            XCTAssertEqual(snapshot.bundleVersion, 1)
            XCTAssertEqual(snapshot.destination?.canonicalSpotID, destination)
            XCTAssertTrue(snapshot.options.map(\.id).contains(destination))
            XCTAssertEqual(snapshot.savedMetadata?.bundleVersion, 1)
            if cancel {
                model.routeOriginStore.cancelSelection()
                XCTAssertNil(model.routeStore.activeDestination)
            } else {
                try await choose(gate, in: model)
                XCTAssertEqual(model.routeStore.activeRoute?.bundleVersion, 1)
                await model.selectedTabChanged(from: .guide, to: .map)
                await model.routeOriginStore.beginOriginChangeForActiveRoute()
                XCTAssertEqual(try options(model.routeOriginStore).destinationSpotID, destination)
                XCTAssertEqual(model.routeOriginStore.session?.currentOriginSpotID, gate)
                try await choose(destination, in: model)
                XCTAssertTrue(model.routeStore.lastOutcome?.allowsOriginSelectionRetry == true)
                await model.routeOriginStore.beginOriginRetryForLastAttempt()
                XCTAssertEqual(try options(model.routeOriginStore).destinationSpotID, destination)
                XCTAssertEqual(model.routeOriginStore.session?.requestedFrom, .home)
                model.routeOriginStore.cancelSelection()
                model.routeStore.endGuidance()
            }
            await model.selectedTabChanged(from: .guide, to: .map)
            await model.routeOriginStore.beginSelection(for: destination, from: .map)
            XCTAssertEqual(try options(model.routeOriginStore).bundleVersion, 2)
            XCTAssertEqual(model.mapStore.contentRevision, 1)
        }
    }

    private func versionedSnapshot(_ version: Int64, withSpots: Bool = true) throws -> PublishedBundleSnapshot {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../")
        let sample = try String(contentsOf: root.appendingPathComponent("docs/schemas/examples/participant-bundle-v2.example.json"),
                                encoding: .utf8).replacingOccurrences(of: "\"mb\"", with: "\"Mb\"")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sample.utf8)) as? [String: Any])
        var meta = try XCTUnwrap(object["nexus_bundle"] as? [String: Any])
        meta["bundle_version"] = version
        object["nexus_bundle"] = meta
        if !withSpots {
            object["spots"] = []
            object["events"] = []
            object["id_aliases"] = []
        }
        return try savedSnapshot(object)
    }

    private func savedSnapshot(_ object: [String: Any]) throws -> PublishedBundleSnapshot {
        let response = BundleFixtures.response(object)
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        let metadata = StoredBundleMetadata(bundleVersion: bundle.meta.bundleVersion, releaseID: bundle.meta.releaseID, schemaVersion: bundle.meta.schemaVersion,
            sha256: response.headers.sha256, byteLength: response.body.count, publishedAt: bundle.meta.publishedAt,
            etag: nil, storedAt: Date(timeIntervalSince1970: 0))
        return .init(stored: .init(bundle: bundle, metadata: metadata), isConfirmedLatest: false, lastConfirmedAt: nil)
    }

    func testCancellationWhileLoadingCannotSetRouteNoticeOrReopenSheet() async throws {
        let model = model()
        await model.routeStore.requestRoute(from: .destination(gate), to: hangar, from: .home)
        let previous = try XCTUnwrap(model.routeStore.activeDestination)
        for result in [ManualRouteOriginCatalog.load(in: RouteCheckFixtures.snapshot, for: hangar),
                       .destinationUnavailable(.unknownSpot(hangar))] {
            let gate = TestGate()
            let client = ManualRouteOriginClient(isConfigured: true, provisionalNotice: nil, loadOptions: { _ in
                await gate.wait()
                return result
            })
            let store = ManualRouteOriginStore(client: client, routeStore: model.routeStore)
            let loading = Task { await store.beginSelection(for: hangar, from: .map) }
            await gate.waitUntilWaiting()
            XCTAssertEqual(store.session?.state, .loading)
            store.cancelSelection()
            await gate.open()
            await loading.value
            XCTAssertNil(store.session)
            XCTAssertEqual(model.routeStore.activeDestination, previous)
            XCTAssertEqual(model.routeStore.lastOutcome, .accepted(previous))
            XCTAssertEqual(model.routeStore.lastAttemptedTab, .home)
        }
        await model.routeOriginStore.beginOriginChangeForActiveRoute()
        model.routeOriginStore.cancelSelection()
        XCTAssertEqual(model.routeStore.activeDestination, previous)
        XCTAssertEqual(model.routeStore.lastOutcome, .accepted(previous))
    }

    func testFailureAndSamePointNeverReplaceGuidanceAndOnlyRelevantNoticesPermitRetry() async throws {
        let model = model()
        let store = model.routeStore
        await store.requestRoute(from: .destination(gate), to: hangar, from: .home)
        let active = try XCTUnwrap(store.activeDestination)
        XCTAssertFalse(RouteRequestOutcome.accepted(active).allowsOriginSelectionRetry)
        let unknown = CanonicalSpotID(rawValue: "HGR_A")
        let ptb = CanonicalSpotID(rawValue: "ptb")
        let otherHangar = CanonicalSpotID(rawValue: "hgr_b")
        let cases: [(RouteOrigin?, CanonicalSpotID, RouteRequestOutcome, Bool)] = [
            (nil, hangar, .unavailable(RouteStateMessages.originRequired), true),
            (.destination(hangar), hangar, .samePoint(.init(destinationSpotID: hangar, displayName: "格納庫A", nodeID: "campus_n_031")), true),
            (.destination(.init(rawValue: "sab")), hangar, .routeFailure(.disconnected(destinationID: hangar, destinationName: "格納庫A")), true),
            (.destination(gate), otherHangar, .routeFailure(.unreachable(destinationID: otherHangar, destinationName: "格納庫B")), true),
            (.destination(gate), ptb, .routeFailure(.notRoutable(.missingAccessNode, destinationID: ptb, destinationName: "実習棟")), false),
            (.destination(ptb), hangar, .routeFailure(.originNotRoutable(.missingAccessNode)), true),
            (.destination(unknown), hangar, .routeFailure(.unknownOrigin(unknown.rawValue)), true),
            (.destination(gate), unknown, .unknownSpot(unknown), false),
        ]
        for (origin, destination, expected, retry) in cases {
            await store.requestRoute(from: origin, to: destination, from: .guide)
            XCTAssertEqual(store.lastOutcome, expected)
            XCTAssertEqual(store.lastOutcome?.allowsOriginSelectionRetry, retry)
            XCTAssertEqual(store.activeDestination, active)
            XCTAssertEqual(store.activeRoute, active.resolvedRoute)
            XCTAssertEqual(store.lastAttemptedDestination, destination)
        }
        store.dismissNotice()
        XCTAssertNil(store.lastAttemptedDestination)
        XCTAssertNil(store.lastAttemptedTab)
        XCTAssertEqual(store.activeDestination, active)
        let unavailable = RouteRequestStore(handler: .bundle(source: .fixed(nil)), initialDestination: active)
        await unavailable.requestRoute(to: hangar, from: .map)
        XCTAssertEqual(unavailable.lastOutcome, .unavailable(RouteStateMessages.dataUnavailable))
        XCTAssertFalse(try XCTUnwrap(unavailable.lastOutcome).allowsOriginSelectionRetry)
        XCTAssertEqual(unavailable.activeDestination, active)
        unavailable.endGuidance()
        XCTAssertNil(unavailable.lastAttemptedTab)
        XCTAssertNil(unavailable.lastAttemptedDestination)
    }

    func testMissingMapOrEdgesReportsNetworkBeforeUnknownDestination() async throws {
        let expected = RouteRequestOutcome.unavailable(RouteStateMessages.networkUnavailable)
        for object in [BundleFixtures.bundleObject(spots: [], map: NSNull()), BundleFixtures.bundleObject()] {
            let snapshot = try savedSnapshot(object)
            XCTAssertEqual(ManualRouteOriginCatalog.load(in: snapshot, for: hangar), .destinationUnavailable(expected))
            let model = model(source: .fixed(snapshot))
            await model.routeOriginStore.beginSelection(for: hangar, from: .map)
            XCTAssertNil(model.routeOriginStore.session)
            XCTAssertEqual(model.routeStore.lastOutcome, expected)
            XCTAssertFalse(expected.allowsOriginSelectionRetry)
        }
    }

    func testMissingSourceUnconfiguredAndFixtureBoundaries() async throws {
        let expected = ManualRouteOriginLoadResult.destinationUnavailable(.unavailable(RouteStateMessages.dataUnavailable))
        for source in [PublishedBundleSource.fixed(nil), .init(current: { throw TestStubError.simulated })] {
            let result = try await ManualRouteOriginClient.bundle(source: source).loadOptions(hangar)
            XCTAssertEqual(result, expected)
        }
        let store = RouteRequestStore(handler: .unconfigured)
        let manual = ManualRouteOriginStore(client: .unconfigured, routeStore: store)
        await manual.beginSelection(for: hangar, from: .map)
        let unconfigured = await RouteRequestHandling.unconfigured.requestRoute(hangar, .map)
        XCTAssertEqual(store.lastOutcome, unconfigured)
        XCTAssertFalse(manual.isPresenting)
        XCTAssertNil(manual.provisionalNotice)
        XCTAssertNil(ManualRouteOriginClient.bundle(source: RouteCheckFixtures.source).provisionalNotice)
        XCTAssertNotNil(ManualRouteOriginClient.bundle(source: RouteCheckFixtures.source, provisionalNotice: RouteCheckFixtures.provisionalNotice).provisionalNotice)
        XCTAssertNil(RouteCheckFixtures.manualDestination(arguments: []))
        XCTAssertEqual(RouteCheckFixtures.manualDestination(arguments: ["-NexusManualRouteCheck", "-NexusLocationFixture", "denied"]), hangar)
        XCTAssertEqual(RouteCheckFixtures.manualDestination(arguments: ["-NexusManualRouteCheck", "Mb"])?.rawValue, "Mb")
    }

    func testRetryLoadKeepsSessionAndItsDestination() async throws {
        let upstream = MutableUpstream(RouteCheckFixtures.snapshot)
        await upstream.fail()
        let store = ManualRouteOriginStore(client: .init(isConfigured: true, provisionalNotice: nil, loadOptions: { id in
            guard let snapshot = try await upstream.read() else { throw TestStubError.simulated }
            return ManualRouteOriginCatalog.load(in: snapshot, for: id)
        }, failureMessage: .testFailure), routeStore: .init(handler: .unconfigured))
        await store.beginSelection(for: hangar, from: .guide, currentOriginSpotID: gate)
        let session = try XCTUnwrap(store.session)
        XCTAssertEqual(session.state, .failed(.testFailure))
        await upstream.set(RouteCheckFixtures.snapshot)
        await store.retryLoad()
        XCTAssertEqual(store.session?.id, session.id)
        XCTAssertEqual(store.session?.currentOriginSpotID, gate)
        XCTAssertEqual(store.session?.requestedFrom, .guide)
        XCTAssertEqual(try options(store).destinationSpotID, hangar)
    }

    func testManualStartWorksAcrossSixUnavailableLocationStates() async throws {
        let deferred = LocationServices(permission: PreviewLocationPermissionProvider(snapshot: .init(authorization: .notDetermined)),
                                        updates: ScriptedLocationUpdatesProvider(coordinates: []))
        let cases: [(LocationServices, LocationPermissionState)] = [
            (CurrentLocationFixture.denied.services, .denied(.userDenied)),
            (CurrentLocationFixture.servicesOff.services, .denied(.servicesOff)),
            (CurrentLocationFixture.restricted.services, .denied(.restricted)),
            (CurrentLocationFixture.failure.services, .unavailable),
            (CurrentLocationFixture.reducedAccuracy.services, .reducedAccuracy),
            (deferred, .deferred),
        ]
        for (services, state) in cases {
            let model = model(services: services)
            let permission = model.currentLocation.permission
            await permission.refresh()
            switch state {
            case .deferred:
                _ = await permission.requestLocation(for: .useAsStartPoint)
                permission.deferExplanation()
            case .unavailable:
                permission.reportAcquisitionFailure()
            default:
                _ = await permission.requestLocation(for: .useAsStartPoint)
            }
            XCTAssertEqual(permission.state, state)
            await model.mapStore.selectOnMap(hangar)
            try await manualHandoff(model)
            try await choose(gate, in: model)
            let route = try XCTUnwrap(model.routeStore.activeRoute)
            XCTAssertEqual(route.origin.id, gate.rawValue)
            XCTAssertEqual(route.destination.id, hangar.rawValue)
            XCTAssertEqual(route.segments.map(\.scope), [.outdoor])
            XCTAssertEqual(permission.state, state)
            XCTAssertNil(permission.guidance)
        }
    }

    func testLocationHandoffPrefersDetailThenActiveThenRetryThenDestinationSearch() async throws {
        let model = model()
        let second = CanonicalSpotID(rawValue: "hgr_b")
        await model.routeStore.requestRoute(from: .destination(gate), to: hangar, from: .guide)
        await model.routeStore.requestRoute(to: second, from: .home)
        await model.mapStore.selectOnMap(gate)
        try await manualHandoff(model)
        XCTAssertEqual(try options(model.routeOriginStore).destinationSpotID, gate)
        model.routeOriginStore.cancelSelection()
        model.mapStore.dismissDetailForRoute()
        try await manualHandoff(model)
        XCTAssertEqual(try options(model.routeOriginStore).destinationSpotID, hangar)
        XCTAssertEqual(model.routeOriginStore.session?.requestedFrom, .guide)
        model.routeOriginStore.cancelSelection()
        model.routeStore.endGuidance()
        await model.routeStore.requestRoute(to: second, from: .home)
        try await manualHandoff(model)
        XCTAssertEqual(try options(model.routeOriginStore).destinationSpotID, second)
        XCTAssertEqual(model.routeOriginStore.session?.requestedFrom, .home)
        model.routeOriginStore.cancelSelection()
        model.routeStore.dismissNotice()
        try await manualHandoff(model)
        XCTAssertTrue(model.mapStore.isSearchActive)
        XCTAssertNil(model.routeOriginStore.session)
    }

    /// 権限画面の同期ボタンが起動する MainActor Task の完了を待つ。
    private func manualHandoff(_ model: AppShellModel) async throws {
        model.currentLocation.permission.chooseStartManually()
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if case .loaded = model.routeOriginStore.session?.state { return }
            if model.mapStore.isSearchActive { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("手動出発地または目的地検索への引き継ぎが完了しなかった")
    }
}
