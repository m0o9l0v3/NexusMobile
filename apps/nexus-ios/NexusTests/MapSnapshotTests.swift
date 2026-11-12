import XCTest
@testable import Nexus

/// Map 全体が1つの版から表示され、切替点でまとめて切り替わること（M1-7、M1 決定記録 §5.1-5）。
///
/// 実際の `MapContentClient.bundle`・`SearchClient.bundle` を `PinnedBundleSource` につなぎ、
/// 地点詳細の地点名（版ごとに変えてある）でどの版から読んだかを確かめる。
@MainActor
final class MapSnapshotTests: XCTestCase {

    @MainActor
    private struct Harness {
        let upstream: MutableUpstream
        let model: AppShellModel
        var mapStore: MapStore { model.mapStore }
    }

    private func makeHarness(initialVersion: Int64 = 1) throws -> Harness {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: initialVersion))
        let pin = PinnedBundleSource(upstream: upstream.source)
        let model = AppShellModel(
            searchClient: .bundle(source: upstream.source),
            mapSearchClient: .bundle(source: pin.source),
            mapContentClient: .bundle(source: pin.source),
            mapSnapshotBoundary: .pinned(pin),
            mapSurface: .unavailable,
            guidanceClient: .unconfigured,
            routeHandler: .unconfigured,
            initialTab: .map
        )
        return Harness(upstream: upstream, model: model)
    }

    private func selection(_ id: CanonicalSpotID) -> MapSelection {
        MapSelection(canonicalSpotID: id, eventID: nil, origin: .map)
    }

    private func displayedName(_ store: MapStore) -> String? {
        if case .loaded(let presentation) = store.detailState {
            return presentation.summary.displayName
        }
        return nil
    }

    /// 版 N の詳細を表示中に版 N+1 が保存されても、別の地点を開いても版 N のまま。
    func testNewVersionIsNotMixedIntoTheDisplayedMap() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.landmarkID))

        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))
        await harness.mapStore.select(selection(PinnedFixtures.roomID))

        XCTAssertEqual(displayedName(harness.mapStore), PinnedFixtures.roomName(version: 1))
        XCTAssertEqual(harness.mapStore.contentRevision, 0)
    }

    /// 詳細を閉じたら Map 全体が新しい版へ切り替わる。
    func testClosingDetailSwitchesTheWholeMap() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))
        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))

        await harness.mapStore.clearSelection()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))

        XCTAssertEqual(harness.mapStore.contentRevision, 1, "描画面が読み直す合図が出ていない")
        XCTAssertEqual(displayedName(harness.mapStore), PinnedFixtures.roomName(version: 2))
    }

    /// Map タブを開き直したら、開いたままの詳細も含めて新しい版へ切り替わる。
    func testReopeningMapTabSwitchesOpenDetailToo() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))
        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))

        await harness.model.selectedTabChanged(from: .map, to: .search)
        XCTAssertEqual(displayedName(harness.mapStore), PinnedFixtures.roomName(version: 1))

        await harness.model.selectedTabChanged(from: .search, to: .map)

        XCTAssertEqual(harness.mapStore.contentRevision, 1)
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID, PinnedFixtures.roomID, "地点は変えない")
        XCTAssertEqual(displayedName(harness.mapStore), PinnedFixtures.roomName(version: 2))
    }

    /// 版が変わっていなければ切り替えない（描画面を無駄に読み直さない）。
    func testBoundaryWithoutNewVersionKeepsRevision() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))

        await harness.mapStore.clearSelection()
        await harness.model.selectedTabChanged(from: .home, to: .map)

        XCTAssertEqual(harness.mapStore.contentRevision, 0)
    }

    /// Map 以外のタブ間の切替は Map の版に触れない。
    func testSwitchingBetweenOtherTabsIsNotABoundary() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))
        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))

        await harness.model.selectedTabChanged(from: .home, to: .search)
        await harness.model.selectedTabChanged(from: .map, to: .map)

        XCTAssertEqual(harness.mapStore.contentRevision, 0)
        XCTAssertEqual(displayedName(harness.mapStore), PinnedFixtures.roomName(version: 1))
    }

    /// Map の検索も表示中の版から読み、切替点で同じ条件のまま新しい版で読み直す。
    func testMapSearchFollowsTheDisplayedVersion() async throws {
        let harness = try makeHarness()
        let search = harness.model.mapSearchStore
        await search.loadInitialIfNeeded()
        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))

        XCTAssertEqual(roomNameInSearch(search), PinnedFixtures.roomName(version: 1))

        await harness.model.selectedTabChanged(from: .guide, to: .map)

        XCTAssertEqual(roomNameInSearch(search), PinnedFixtures.roomName(version: 2))
    }

    /// 探すタブは Map の固定に縛られず、保存ポインタの最新を読む。
    func testSearchTabIsNotPinnedByMap() async throws {
        let harness = try makeHarness()
        await harness.mapStore.select(selection(PinnedFixtures.roomID))
        await harness.upstream.set(try PinnedFixtures.snapshot(version: 2))

        await harness.model.searchStore.loadInitialIfNeeded()

        XCTAssertEqual(roomNameInSearch(harness.model.searchStore), PinnedFixtures.roomName(version: 2))
    }

    /// 閉じた後に古い読み込みが終わっても、詳細を開き直さない。
    func testLateDetailResultAfterCloseIsDiscarded() async {
        let gate = TestGate()
        let store = MapStore(client: .stub(spotDetail: { _ in
            await gate.wait()
            return .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A))
        }))

        let loading = Task { await store.select(self.selection(PinnedFixtures.roomID)) }
        await gate.waitUntilWaiting()
        await store.clearSelection()
        await gate.open()
        await loading.value

        XCTAssertEqual(store.detailState, .none)
        XCTAssertNil(store.selection)
    }

    private func roomNameInSearch(_ store: SearchStore) -> String? {
        let spots: [SpotSummary]
        switch store.state {
        case .initial(let snapshot):
            spots = snapshot.spots
        case .results(let snapshot), .saved(let snapshot, _):
            spots = snapshot.spots
        default:
            return nil
        }
        return spots.first { $0.canonicalSpotID == PinnedFixtures.roomID }?.displayName
    }
}

/// 検索の読み込みが重なったとき、後から始めた読み込みの結果を残す（PR #142 のレビュー）。
@MainActor
final class SearchStoreReloadTests: XCTestCase {

    private func initial(_ name: String) -> SearchInitialFetchResult {
        .fresh(SearchInitialSnapshot(
            headingText: "すべての地点",
            spots: [SpotSummary(
                canonicalSpotID: PinnedFixtures.roomID,
                displayName: name,
                kind: nil,
                buildingName: nil,
                floorName: nil
            )]
        ))
    }

    /// 版切替前に始まった初期一覧の読み込みが、切替後の読み直しより遅れて終わっても上書きしない。
    func testStaleInitialLoadDoesNotOverwriteReload() async {
        let gate = TestGate()
        let calls = SendableBox(0)
        let oldResult = initial("旧版の名前")
        let newResult = initial("新版の名前")
        let store = SearchStore(
            client: .stub(initial: {
                let call = await calls.increment()
                if call == 1 {
                    await gate.wait()
                    return oldResult
                }
                return newResult
            }),
            history: SearchHistoryStore(),
            surface: .map
        )

        let stale = Task { await store.loadInitialIfNeeded() }
        await gate.waitUntilWaiting()
        await store.reloadIfLoaded()
        await gate.open()
        await stale.value

        guard case .initial(let snapshot) = store.state else {
            return XCTFail("初期一覧にならなかった: \(store.state)")
        }
        XCTAssertEqual(snapshot.spots.first?.displayName, "新版の名前")
    }

    /// 版切替前に始まった検索が遅れて終わっても、切替後の検索結果を上書きしない。
    func testStaleSearchDoesNotOverwriteReload() async {
        let gate = TestGate()
        let calls = SendableBox(0)
        let store = SearchStore(
            client: .stub(search: { query in
                let call = await calls.increment()
                if call == 1 {
                    await gate.wait()
                    return .fresh(SearchResultsSnapshot(query: query, spots: []))
                }
                return .empty(.testFailure)
            }),
            history: SearchHistoryStore(),
            surface: .map
        )
        store.draftText = "教室"

        let stale = Task { await store.submit() }
        await gate.waitUntilWaiting()
        await store.reloadIfLoaded()
        await gate.open()
        await stale.value

        guard case .empty = store.state else {
            return XCTFail("後から始めた検索の結果が残らなかった: \(store.state)")
        }
    }
}
