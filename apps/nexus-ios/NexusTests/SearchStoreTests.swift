import XCTest
@testable import Nexus

@MainActor
final class SearchStoreTests: XCTestCase {

    /// 既定引数で `@MainActor` 隔離のイニシャライザを呼べないため nil 既定にする。
    private func makeStore(
        client: SearchClient,
        history: SearchHistoryStore? = nil,
        surface: SearchSurface = .search
    ) -> SearchStore {
        SearchStore(
            client: client,
            history: history ?? SearchHistoryStore(),
            surface: surface
        )
    }

    func testInitialContentLoadsIntoInitialState() async {
        let store = makeStore(
            client: .stub(initial: {
                .fresh(SearchInitialSnapshot(headingText: "すべての地点", spots: [TestSpots.classroom2A]))
            })
        )

        await store.loadInitialIfNeeded()

        guard case .initial(let snapshot) = store.state else {
            return XCTFail("初期状態にならなかった: \(store.state)")
        }
        XCTAssertEqual(snapshot.spots.count, 1)
        XCTAssertEqual(snapshot.totalCount, 1)
    }

    func testSubmitProducesResults() async {
        let store = makeStore(
            client: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            })
        )

        store.draftText = "2A"
        await store.submit()

        guard case .results(let snapshot) = store.state else {
            return XCTFail("結果状態にならなかった: \(store.state)")
        }
        XCTAssertEqual(snapshot.spots.first?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertEqual(store.phase, .results)
    }

    /// 0件と取得失敗を同一視しない（v04「取得失敗を0件にしない」）。
    func testEmptyResultStaysDistinctFromFailure() async {
        let store = makeStore(
            client: .stub(search: { _ in .empty(NexusStateMessage(title: "0件", systemImageName: "magnifyingglass")) })
        )

        store.draftText = "存在しない語"
        await store.submit()

        guard case .empty(let message) = store.state else {
            return XCTFail("0件状態にならなかった: \(store.state)")
        }
        XCTAssertEqual(message.title, "0件")
        if case .failed = store.state {
            XCTFail("0件が失敗として扱われた")
        }
    }

    func testThrownErrorBecomesConfiguredFailure() async {
        let store = makeStore(
            client: .stub(search: { _ in throw TestStubError.simulated })
        )

        store.draftText = "2A"
        await store.submit()

        guard case .failed(let message) = store.state else {
            return XCTFail("失敗状態にならなかった: \(store.state)")
        }
        XCTAssertEqual(message, .testFailure)
    }

    func testSavedResultCarriesMetadata() async {
        let metadata = NexusSavedMetadata(title: "保存版", detail: "最新確認不可")
        let store = makeStore(
            client: .stub(search: { query in
                .saved(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]), metadata)
            })
        )

        store.draftText = "2A"
        await store.submit()

        guard case .saved(_, let received) = store.state else {
            return XCTFail("保存版状態にならなかった: \(store.state)")
        }
        XCTAssertEqual(received, metadata)
    }

    /// canonical ID は大小文字を含めて無加工で保持され、大小文字違いは別地点になる。
    func testResultsPreserveCanonicalIDsVerbatimIncludingCaseVariants() async {
        let store = makeStore(
            client: .stub(search: { query in
                .fresh(
                    SearchResultsSnapshot(
                        query: query,
                        spots: [TestSpots.classroom2A, TestSpots.classroom2AUpperCase]
                    )
                )
            })
        )

        store.draftText = "2A"
        await store.submit()

        guard case .results(let snapshot) = store.state else {
            return XCTFail("結果状態にならなかった")
        }
        let ids = snapshot.spots.map(\.canonicalSpotID.rawValue)
        XCTAssertEqual(ids, ["mb_f2_cr_2a", "Mb_F2_CR_2A"])
        XCTAssertEqual(Set(snapshot.spots.map(\.canonicalSpotID)).count, 2)
    }

    /// タブを往復しても検索条件と状態が保持される。
    func testStateAndQuerySurviveSimulatedTabSwitch() async {
        let router = AppRouter()
        let store = makeStore(
            client: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            })
        )

        store.draftText = "2A"
        await store.submit()
        let stateBefore = store.state
        let queryBefore = store.committedQuery

        router.activate(.map)
        router.activate(.guide)
        router.activate(.search)

        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(store.committedQuery, queryBefore)
    }

    func testClearConditionsResetsQueryButKeepsHistory() async {
        let history = SearchHistoryStore()
        let store = makeStore(
            client: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            }),
            history: history
        )

        store.draftText = "2A"
        await store.submit()
        XCTAssertEqual(history.entries.count, 1)

        await store.clearConditions()

        XCTAssertEqual(store.committedQuery, .empty)
        XCTAssertEqual(store.draftText, "")
        XCTAssertEqual(store.phase, .initial)
        XCTAssertEqual(history.entries.count, 1, "条件解除で履歴を消さない")
    }

    func testCategorySelectionRefetchesWithSameText() async {
        let received = SendableBox<SearchQuery?>(nil)
        let store = makeStore(
            client: .stub(search: { query in
                await received.set(query)
                return .fresh(SearchResultsSnapshot(query: query, spots: []))
            })
        )

        store.draftText = "2A"
        await store.selectCategory(.classroom)

        let value = await received.get()
        XCTAssertEqual(value?.text, "2A")
        XCTAssertEqual(value?.categoryID, .classroom)
    }

    /// Map の検索と探すの検索は状態を共有しない。履歴だけ共有する。
    func testMapSurfaceStoreIsIndependentOfSearchTabStore() async {
        let history = SearchHistoryStore()
        let client = SearchClient.stub(search: { query in
            .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
        })
        let searchTabStore = makeStore(client: client, history: history, surface: .search)
        let mapStore = makeStore(client: client, history: history, surface: .map)

        searchTabStore.draftText = "2A"
        await searchTabStore.submit()
        let searchStateBefore = searchTabStore.state

        mapStore.draftText = "格納庫"
        await mapStore.submit()

        XCTAssertEqual(searchTabStore.state, searchStateBefore)
        XCTAssertEqual(searchTabStore.committedQuery.text, "2A")
        XCTAssertEqual(mapStore.committedQuery.text, "格納庫")
    }

    func testSharedHistoryReceivesSubmissionsFromBothSurfaces() async {
        let history = SearchHistoryStore()
        let client = SearchClient.stub(search: { query in
            .fresh(SearchResultsSnapshot(query: query, spots: []))
        })
        let searchTabStore = makeStore(client: client, history: history, surface: .search)
        let mapSurfaceStore = makeStore(client: client, history: history, surface: .map)

        searchTabStore.draftText = "2A"
        await searchTabStore.submit()
        mapSurfaceStore.draftText = "格納庫"
        await mapSurfaceStore.submit()

        XCTAssertEqual(history.entries.map(\.text), ["格納庫", "2A"])
        XCTAssertEqual(searchTabStore.historyEntries.count, 2)
        XCTAssertEqual(mapSurfaceStore.historyEntries.count, 2)
    }
}

@MainActor
final class SearchHistoryStoreTests: XCTestCase {
    func testRecordsMostRecentFirst() {
        let history = SearchHistoryStore()
        history.record(SearchQuery(text: "A"))
        history.record(SearchQuery(text: "B"))

        XCTAssertEqual(history.entries.map(\.text), ["B", "A"])
    }

    func testDeduplicatesIdenticalQueries() {
        let history = SearchHistoryStore()
        history.record(SearchQuery(text: "A"))
        history.record(SearchQuery(text: "B"))
        history.record(SearchQuery(text: "A"))

        XCTAssertEqual(history.entries.map(\.text), ["A", "B"])
    }

    func testTruncatesToLimit() {
        let history = SearchHistoryStore(limit: 2)
        history.record(SearchQuery(text: "A"))
        history.record(SearchQuery(text: "B"))
        history.record(SearchQuery(text: "C"))

        XCTAssertEqual(history.entries.map(\.text), ["C", "B"])
    }

    func testCaseSensitiveQueriesAreDistinctEntries() {
        let history = SearchHistoryStore()
        history.record(SearchQuery(text: "2a"))
        history.record(SearchQuery(text: "2A"))

        XCTAssertEqual(history.entries.count, 2)
    }

    func testBlankQueryIsNotRecorded() {
        let history = SearchHistoryStore()
        history.record(.empty)
        history.record(SearchQuery(text: "   "))

        XCTAssertTrue(history.entries.isEmpty)
    }
}
