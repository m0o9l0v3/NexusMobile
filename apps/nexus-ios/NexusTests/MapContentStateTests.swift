import XCTest
@testable import Nexus

/// Map の地図の状態：読込中・掲載なし・失敗・地図あり（#31）。
///
/// 工程3の条件「通信失敗を0件にしない」を、保存版が無い理由ごとに確かめる。
@MainActor
final class MapContentStateTests: XCTestCase {

    // MARK: - 結果から状態へ

    func testNotPublishedIsEmptyWithoutRetry() {
        let state = MapContentState.resolve(.success(nil), absence: .notPublished)

        XCTAssertEqual(state, .empty(MapContentStateMessage.notPublished))
        XCTAssertFalse(state.allowsRetry)
    }

    /// 通信の失敗・理由不明・読み出しの失敗は、どれも「掲載なし」にしない。再試行を出す。
    func testFailuresAreNeverShownAsEmpty() {
        let cases: [(Result<PublishedBundleSnapshot?, Error>, PublishedBundleAbsence)] = [
            (.success(nil), .checkFailed),
            (.success(nil), .unknown),
            (.failure(TestStubError.simulated), .unknown),
            (.failure(TestStubError.simulated), .notPublished),
        ]
        for (result, absence) in cases {
            let state = MapContentState.resolve(result, absence: absence)
            XCTAssertEqual(state, .failed(MapContentStateMessage.loadFailed), "\(absence)")
            XCTAssertTrue(state.allowsRetry)
        }
    }

    func testUpdateRequiredIsAFailureWithItsOwnMessage() {
        XCTAssertEqual(
            MapContentState.resolve(.success(nil), absence: .updateRequired),
            .failed(MapContentStateMessage.updateRequired)
        )
    }

    /// 4つの状態の文言は互いに違う（同じ見た目に潰さない）。未提供（接続先なし）も別の文言。
    func testStateMessagesAreDistinct() {
        let titles = [
            MapContentStateMessage.loadingTitle,
            MapContentStateMessage.notProvided.title,
            MapContentStateMessage.notPublished.title,
            MapContentStateMessage.noMapInBundle.title,
            MapContentStateMessage.loadFailed.title,
            MapContentStateMessage.updateRequired.title,
        ]
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testStateViewKindMatchesRetryRule() {
        XCTAssertEqual(MapSurfaceStateView.Kind(.loading), .loading)
        XCTAssertNil(MapSurfaceStateView.Kind(.loaded(CampusMapContent(buildings: [], pins: []))))
        XCTAssertEqual(
            MapSurfaceStateView.Kind(.empty(MapContentStateMessage.notPublished)),
            .message(MapContentStateMessage.notPublished, allowsRetry: false)
        )
        XCTAssertEqual(
            MapSurfaceStateView.Kind(.failed(MapContentStateMessage.loadFailed)),
            .message(MapContentStateMessage.loadFailed, allowsRetry: true)
        )
    }

    // MARK: - MapContentStore

    func testStartsLoadingAndResolvesToMap() async throws {
        let store = MapContentStore(source: .fixed(try PinnedFixtures.snapshot(version: 1)))
        XCTAssertEqual(store.state, .loading)

        await store.load()

        guard case .loaded(let content) = store.state else {
            return XCTFail("地図にならなかった: \(store.state)")
        }
        XCTAssertEqual(content.buildings.map(\.id), ["mb"])
    }

    func testNotPublishedSourceIsEmpty() async {
        let store = MapContentStore(source: .fixed(nil, absence: .notPublished))

        await store.load()

        XCTAssertEqual(store.state, .empty(MapContentStateMessage.notPublished))
    }

    /// 再試行：取得元にすぐ確認させ、版の切替点を通してから読み直す。新しい版が保存されていれば地図になる。
    /// 地図・地点詳細・検索は同じ固定（PinnedBundleSource）から読むので、地図だけ別の版にならない。
    func testRetryRechecksAdvancesAndShowsTheNewVersion() async throws {
        let upstream = RecheckableUpstream()
        let pin = PinnedBundleSource(upstream: upstream.source)
        let store = MapContentStore(source: pin.source)

        await store.load()
        XCTAssertEqual(store.state, .failed(MapContentStateMessage.loadFailed))

        await upstream.publishOnNextRecheck(try PinnedFixtures.snapshot(version: 3))
        var advanced = false
        await store.retry {
            advanced = await pin.advance()
        }

        let rechecks = await upstream.recheckCount
        XCTAssertEqual(rechecks, 1)
        XCTAssertTrue(advanced, "再試行で版の切替点を通す")
        guard case .loaded = store.state else {
            return XCTFail("再試行のあと地図にならなかった: \(store.state)")
        }
        let pinned = try await pin.current()
        XCTAssertEqual(pinned?.stored.metadata.bundleVersion, 3)
    }

    func testRetryStillFailingStaysFailed() async {
        let upstream = RecheckableUpstream()
        let store = MapContentStore(source: upstream.source)
        await store.load()

        await store.retry {}

        XCTAssertEqual(store.state, .failed(MapContentStateMessage.loadFailed))
        let rechecks = await upstream.recheckCount
        XCTAssertEqual(rechecks, 1)
    }

    func testRetryIsIgnoredUnlessFailed() async {
        let upstream = RecheckableUpstream(absence: .notPublished)
        let store = MapContentStore(source: upstream.source)
        await store.load()

        await store.retry {}

        let rechecks = await upstream.recheckCount
        XCTAssertEqual(rechecks, 0, "掲載なしには再試行を出さない")
    }

    /// 地図を出したまま版を読み直すときは、読込中を挟まない（地図が一瞬消えない）。
    func testReloadKeepsTheMapWhileReading() async throws {
        let upstream = RecheckableUpstream(snapshot: try PinnedFixtures.snapshot(version: 1))
        let store = MapContentStore(source: upstream.source)
        await store.load()
        let gate = TestGate()
        await upstream.gateNextRead(gate)

        let reload = Task { await store.load() }
        await gate.waitUntilWaiting()
        XCTAssertTrue(store.state.isLoaded)
        await gate.open()
        await reload.value
        XCTAssertTrue(store.state.isLoaded)
    }

    // MARK: - 現在地ボタンの位置情報オフ

    func testLocationOffCoversDeniedReasonsOnly() async {
        let cases: [(LocationPermissionSnapshot, Bool)] = [
            (LocationPermissionSnapshot(authorization: .denied), true),
            (LocationPermissionSnapshot(authorization: .denied, servicesEnabled: false), true),
            (LocationPermissionSnapshot(authorization: .restricted), true),
            (LocationPermissionSnapshot(authorization: .notDetermined), false),
            (LocationPermissionSnapshot(authorization: .authorizedWhenInUse), false),
            (LocationPermissionSnapshot(authorization: .authorizedWhenInUse, accuracy: .reduced), false),
        ]
        for (snapshot, expected) in cases {
            let provider = StubLocationPermissionProvider(snapshot)
            let store = CurrentLocationStore(
                permission: LocationPermissionStore(provider: provider),
                updates: StubLocationUpdatesProvider()
            )
            await store.permission.refresh()
            XCTAssertEqual(store.isLocationOff, expected, "\(snapshot)")
            // Map を開いて設定を読んだだけでは、説明も理由の表示も出さない（#25 の決定 A）。
            XCTAssertFalse(store.permission.isExplanationPresented)
            XCTAssertNil(store.permission.guidance)
        }
    }

    func testLocationOffButtonValue() {
        XCTAssertEqual(
            CurrentLocationAccessibilityText.buttonValue(phase: .idle, isFollowing: false, isLocationOff: true),
            "位置情報オフ"
        )
        XCTAssertEqual(CurrentLocationAccessibilityText.buttonValue(phase: .idle, isFollowing: false), "")
    }
}

/// 確認（`recheck`）のたびに数え、指定した版を「確認で保存された」ことにする上流。
private actor RecheckableUpstream {
    private var snapshot: PublishedBundleSnapshot?
    private var absenceValue: PublishedBundleAbsence
    private var pendingPublish: PublishedBundleSnapshot?
    private var nextReadGate: TestGate?
    private(set) var recheckCount = 0

    init(snapshot: PublishedBundleSnapshot? = nil, absence: PublishedBundleAbsence = .checkFailed) {
        self.snapshot = snapshot
        self.absenceValue = absence
    }

    func publishOnNextRecheck(_ snapshot: PublishedBundleSnapshot) {
        pendingPublish = snapshot
    }

    func gateNextRead(_ gate: TestGate) {
        nextReadGate = gate
    }

    func read() async -> PublishedBundleSnapshot? {
        let captured = snapshot
        if let gate = nextReadGate {
            nextReadGate = nil
            await gate.wait()
        }
        return captured
    }

    func absence() -> PublishedBundleAbsence { absenceValue }

    func recheck() {
        recheckCount += 1
        if let pendingPublish {
            snapshot = pendingPublish
            self.pendingPublish = nil
            absenceValue = .unknown
        }
    }

    nonisolated var source: PublishedBundleSource {
        PublishedBundleSource(
            current: { await self.read() },
            absence: { await self.absence() },
            recheck: { await self.recheck() }
        )
    }
}
