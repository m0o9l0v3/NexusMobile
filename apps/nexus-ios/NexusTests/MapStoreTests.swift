import XCTest
@testable import Nexus

@MainActor
final class MapStoreTests: XCTestCase {

    private func selection(_ rawValue: String, eventID: String? = nil) -> MapSelection {
        MapSelection(
            canonicalSpotID: CanonicalSpotID(rawValue: rawValue),
            eventID: eventID,
            origin: .search
        )
    }

    func testSelectLoadsDetailForExactCanonicalID() async {
        let received = SendableBox<CanonicalSpotID?>(nil)
        let store = MapStore(client: .stub(spotDetail: { id in
            await received.set(id)
            return .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A))
        }))

        await store.select(selection("mb_2f_cl_001"))

        let value = await received.get()
        XCTAssertEqual(value?.rawValue, "mb_2f_cl_001")
        guard case .loaded = store.detailState else {
            return XCTFail("読み込み済みにならなかった: \(store.detailState)")
        }
    }

    /// 未知IDを受付など別地点へ置換しない。
    func testUnknownSpotProducesUnknownStateWithoutSubstitution() async {
        let store = MapStore(client: .stub(spotDetail: { .unknownSpot($0) }))

        await store.select(selection("does_not_exist"))

        guard case .unknown(let id) = store.detailState else {
            return XCTFail("未知状態にならなかった: \(store.detailState)")
        }
        XCTAssertEqual(id.rawValue, "does_not_exist")
        XCTAssertEqual(store.selection?.canonicalSpotID.rawValue, "does_not_exist")
    }

    func testCaseDifferentIdentifiersAreTreatedAsDistinctSpots() async {
        let calls = SendableBox<[String]>([])
        let store = MapStore(client: .stub(spotDetail: { id in
            await calls.append(id.rawValue)
            return .unknownSpot(id)
        }))

        await store.select(selection("mb_2f_cl_001"))
        await store.select(selection("MB_2F_CL_001"))

        let recorded = await calls.get()
        XCTAssertEqual(recorded, ["mb_2f_cl_001", "MB_2F_CL_001"])
    }

    func testFailedDetailKeepsSelectionForRetry() async {
        let store = MapStore(client: .stub(spotDetail: { _ in throw TestStubError.simulated }))

        await store.select(selection("mb_2f_cl_001"))

        guard case .failed(let id, let message) = store.detailState else {
            return XCTFail("失敗状態にならなかった: \(store.detailState)")
        }
        XCTAssertEqual(id.rawValue, "mb_2f_cl_001")
        XCTAssertEqual(message, .testFailure)
        XCTAssertNotNil(store.selection)
    }

    func testRetryAfterFailureReusesSameCanonicalID() async {
        let calls = SendableBox<[String]>([])
        let store = MapStore(client: .stub(spotDetail: { id in
            await calls.append(id.rawValue)
            throw TestStubError.simulated
        }))

        await store.select(selection("mb_2f_cl_001"))
        await store.retryDetail()

        let recorded = await calls.get()
        XCTAssertEqual(recorded, ["mb_2f_cl_001", "mb_2f_cl_001"])
    }

    func testSavedDetailCarriesMetadata() async {
        let metadata = NexusSavedMetadata(title: "保存版", detail: nil)
        let store = MapStore(client: .stub(spotDetail: { _ in
            .saved(SpotDetailPresentation(summary: TestSpots.classroom2A), metadata)
        }))

        await store.select(selection("mb_2f_cl_001"))

        guard case .saved(_, let received) = store.detailState else {
            return XCTFail("保存版状態にならなかった: \(store.detailState)")
        }
        XCTAssertEqual(received, metadata)
    }

    func testEventContextIsCarriedIntoSelection() async {
        let store = MapStore(client: .stub(spotDetail: { _ in
            .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A))
        }))

        await store.select(selection("mb_2f_cl_001", eventID: "PREVIEW_EVENT_DRONE"))

        XCTAssertEqual(store.selection?.eventID, "PREVIEW_EVENT_DRONE")
    }

    // MARK: - イベント欄（#48）

    private static let eventSection = SpotEventSection.published(SpotEventDetail(
        eventID: "event-1",
        title: "模擬授業",
        category: "体験授業",
        descriptionText: nil,
        slots: []
    ))

    /// 受け取ったイベント ID ごとにイベント欄を返す取得境界。
    private func eventAwareClient(recording calls: SendableBox<[String?]>) -> MapContentClient {
        MapContentClient(
            detail: { _, eventID in
                await calls.append(eventID)
                return .fresh(SpotDetailPresentation(
                    summary: TestSpots.classroom2A,
                    event: eventID.map { $0 == "event-1" ? Self.eventSection : .notPublished(eventID: $0) }
                ))
            },
            failureMessage: .testFailure
        )
    }

    /// Home の「詳細」から来たら、イベント ID を取得境界に渡し、イベント欄を持つ詳細になる。
    func testEventSelectionLoadsEventSection() async {
        let calls = SendableBox<[String?]>([])
        let store = MapStore(client: eventAwareClient(recording: calls))

        await store.select(selection("mb_2f_cl_001", eventID: "event-1"))

        let recorded = await calls.get()
        XCTAssertEqual(recorded, ["event-1"])
        guard case .loaded(let presentation) = store.detailState else {
            return XCTFail("読み込み済みにならなかった: \(store.detailState)")
        }
        XCTAssertEqual(presentation.event, Self.eventSection)
    }

    /// 版にないイベントは掲載されていない状態として持ち、地点詳細そのものは失敗にしない。
    func testMissingEventStaysAsNotPublished() async {
        let store = MapStore(client: eventAwareClient(recording: SendableBox([])))

        await store.select(selection("mb_2f_cl_001", eventID: "withdrawn"))

        guard case .loaded(let presentation) = store.detailState else {
            return XCTFail("読み込み済みにならなかった: \(store.detailState)")
        }
        XCTAssertEqual(presentation.event, .notPublished(eventID: "withdrawn"))
    }

    /// 地図上で地点を選び直したら、前のイベントを引き継がない。
    func testSelectingOnMapDropsTheEvent() async {
        let calls = SendableBox<[String?]>([])
        let store = MapStore(client: eventAwareClient(recording: calls))

        await store.select(selection("mb_2f_cl_001", eventID: "event-1"))
        await store.selectOnMap(CanonicalSpotID(rawValue: "mb"))

        let recorded = await calls.get()
        XCTAssertEqual(recorded, ["event-1", nil])
        guard case .loaded(let presentation) = store.detailState else {
            return XCTFail("読み込み済みにならなかった: \(store.detailState)")
        }
        XCTAssertNil(presentation.event)
    }

    /// 再試行と版の切替後の読み直しでも、同じイベントを読み直す（M1-7）。
    func testRetryAndSnapshotReloadKeepTheEvent() async {
        let calls = SendableBox<[String?]>([])
        let store = MapStore(
            client: eventAwareClient(recording: calls),
            snapshotBoundary: MapSnapshotBoundary(advance: { true })
        )

        await store.select(selection("mb_2f_cl_001", eventID: "event-1"))
        await store.retryDetail()
        await store.mapTabDidOpen()

        let recorded = await calls.get()
        XCTAssertEqual(recorded, ["event-1", "event-1", "event-1"])
        XCTAssertEqual(store.selection?.eventID, "event-1")
    }

    func testClearSelectionDoesNotTouchRouteDestination() async {
        let routeStore = RouteRequestStore(handler: .alwaysAccepting)
        let store = MapStore(client: .stub(spotDetail: { _ in
            .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A))
        }))

        await routeStore.requestRoute(to: CanonicalSpotID(rawValue: "mb_2f_cl_001"), from: .map)
        await store.select(selection("hgr_a"))
        await store.clearSelection()

        XCTAssertNil(store.selection)
        XCTAssertEqual(routeStore.activeDestination?.canonicalSpotID.rawValue, "mb_2f_cl_001")
    }
}

@MainActor
final class RouteRequestStoreTests: XCTestCase {

    func testAcceptedOutcomeSetsActiveDestination() async {
        let store = RouteRequestStore(handler: .alwaysAccepting)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "mb_2f_cl_001"), from: .search)

        XCTAssertEqual(store.activeDestination?.canonicalSpotID.rawValue, "mb_2f_cl_001")
        XCTAssertEqual(store.activeDestination?.requestedFrom, .search)
    }

    func testUnknownSpotOutcomeKeepsPreviousDestination() async {
        let outcomes = SendableBox<Int>(0)
        let handler = RouteRequestHandling { id, tab in
            let count = await outcomes.increment()
            return count == 1
                ? .accepted(RouteDestination(canonicalSpotID: id, requestedFrom: tab))
                : .unknownSpot(id)
        }
        let store = RouteRequestStore(handler: handler)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "spot_a"), from: .map)
        await store.requestRoute(to: CanonicalSpotID(rawValue: "spot_b"), from: .map)

        XCTAssertEqual(store.activeDestination?.canonicalSpotID.rawValue, "spot_a")
        guard case .unknownSpot(let id) = store.lastOutcome else {
            return XCTFail("未知結果にならなかった")
        }
        XCTAssertEqual(id.rawValue, "spot_b")
    }

    func testUnavailableOutcomeKeepsPreviousDestination() async {
        let outcomes = SendableBox<Int>(0)
        let handler = RouteRequestHandling { id, tab in
            let count = await outcomes.increment()
            return count == 1
                ? .accepted(RouteDestination(canonicalSpotID: id, requestedFrom: tab))
                : .unavailable(.testFailure)
        }
        let store = RouteRequestStore(handler: handler)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "spot_a"), from: .map)
        await store.requestRoute(to: CanonicalSpotID(rawValue: "spot_b"), from: .map)

        XCTAssertEqual(store.activeDestination?.canonicalSpotID.rawValue, "spot_a")
    }

    func testUnconfiguredHandlerReportsNotProvidedAndSetsNoDestination() async {
        let store = RouteRequestStore(handler: .unconfigured)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "mb_2f_cl_001"), from: .map)

        XCTAssertNil(store.activeDestination)
        guard case .unavailable(let message) = store.lastOutcome else {
            return XCTFail("未提供結果にならなかった")
        }
        XCTAssertEqual(message.title, "経路案内は未提供です")
    }

    func testRequestPreservesCanonicalIDCase() async {
        let received = SendableBox<CanonicalSpotID?>(nil)
        let handler = RouteRequestHandling { id, tab in
            await received.set(id)
            return .accepted(RouteDestination(canonicalSpotID: id, requestedFrom: tab))
        }
        let store = RouteRequestStore(handler: handler)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "Mb_2F_CL_001"), from: .guide)

        let value = await received.get()
        XCTAssertEqual(value?.rawValue, "Mb_2F_CL_001")
        XCTAssertEqual(store.activeDestination?.canonicalSpotID.rawValue, "Mb_2F_CL_001")
    }

    func testOriginTabIsRecordedOnDestination() async {
        let store = RouteRequestStore(handler: .alwaysAccepting)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "mb_2f_cl_001"), from: .home)

        XCTAssertEqual(store.activeDestination?.requestedFrom, .home)
    }

    func testDismissNoticeClearsOutcomeButKeepsDestination() async {
        let store = RouteRequestStore(handler: .alwaysAccepting)

        await store.requestRoute(to: CanonicalSpotID(rawValue: "mb_2f_cl_001"), from: .map)
        store.dismissNotice()

        XCTAssertNil(store.lastOutcome)
        XCTAssertNotNil(store.activeDestination)
    }
}

extension SendableBox where Value == Int {
    func increment() -> Int {
        let next = get() + 1
        set(next)
        return next
    }
}

extension SendableBox where Value == [String] {
    func append(_ element: String) {
        var next = get()
        next.append(element)
        set(next)
    }
}

extension SendableBox where Value == [String?] {
    func append(_ element: String?) {
        var next = get()
        next.append(element)
        set(next)
    }
}
