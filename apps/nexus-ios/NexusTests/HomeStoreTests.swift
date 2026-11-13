import XCTest
@testable import Nexus

@MainActor
final class HomeStoreTests: XCTestCase {
    func testFreshResultBecomesLoaded() async {
        let snapshot = makeSnapshot()
        let store = HomeStore(client: makeClient(result: .fresh(snapshot)))

        await store.loadIfNeeded()

        XCTAssertEqual(store.state, .loaded(snapshot))
    }

    func testEmptyResultStaysDistinctFromFailure() async {
        let message = HomeStateMessage(
            title: "empty",
            detail: nil,
            systemImageName: "tray"
        )
        let store = HomeStore(client: makeClient(result: .empty(message)))

        await store.loadIfNeeded()

        XCTAssertEqual(store.state, .empty(message))
    }

    func testSavedResultCarriesMetadata() async {
        let snapshot = makeSnapshot()
        let metadata = SavedHomeMetadata(title: "saved", detail: "offline")
        let store = HomeStore(client: makeClient(result: .saved(snapshot, metadata)))

        await store.loadIfNeeded()

        XCTAssertEqual(store.state, .saved(snapshot, metadata))
    }

    func testThrownErrorBecomesConfiguredFailure() async {
        let failure = HomeStateMessage(
            title: "failure",
            detail: "retry",
            systemImageName: "wifi.slash"
        )
        let client = HomeClient(
            fetch: { throw StubError.failed },
            failureMessage: failure
        )
        let store = HomeStore(client: client)

        await store.loadIfNeeded()

        XCTAssertEqual(store.state, .failed(failure))
    }

    func testSavedEmptyResultKeepsSavedMetadata() async {
        let message = HomeStateMessage(title: "empty", detail: nil, systemImageName: "tray")
        let metadata = SavedHomeMetadata(title: "saved", detail: "offline")
        let store = HomeStore(client: makeClient(result: .empty(message, saved: metadata)))

        await store.loadIfNeeded()

        XCTAssertEqual(store.state, .empty(message, saved: metadata))
    }

    func testRefreshFromIdleLoads() async {
        let snapshot = makeSnapshot()
        let store = HomeStore(client: makeClient(result: .fresh(snapshot)))

        await store.refresh()

        XCTAssertEqual(store.state, .loaded(snapshot))
    }

    /// 読み込み済みでも、境界で読み直して新しい結果に差し替える（#48）。
    func testRefreshReplacesLoadedContent() async {
        let results = ResultSequence([.fresh(makeSnapshot()), .saved(makeSnapshot(), SavedHomeMetadata(title: "saved", detail: nil))])
        let store = HomeStore(client: HomeClient(fetch: { try results.next() }, failureMessage: failure))

        await store.loadIfNeeded()
        await store.loadIfNeeded()
        XCTAssertEqual(store.state, .loaded(makeSnapshot()), "loadIfNeeded は読み直さない")

        await store.refresh()
        XCTAssertEqual(store.state, .saved(makeSnapshot(), SavedHomeMetadata(title: "saved", detail: nil)))
    }

    /// 読み直しに失敗しても、表示中の内容を失敗の表示に替えない。
    func testFailedRefreshKeepsShownContent() async {
        let results = ResultSequence([.fresh(makeSnapshot())])
        let store = HomeStore(client: HomeClient(fetch: { try results.next() }, failureMessage: failure))

        await store.loadIfNeeded()
        await store.refresh()

        XCTAssertEqual(store.state, .loaded(makeSnapshot()))
    }

    func testRefreshAfterFailureLoadsAgain() async {
        let results = ResultSequence([], thenReturn: .fresh(makeSnapshot()))
        let store = HomeStore(client: HomeClient(fetch: { try results.next() }, failureMessage: failure))

        await store.loadIfNeeded()
        XCTAssertEqual(store.state, .failed(failure))

        results.recover()
        await store.refresh()
        XCTAssertEqual(store.state, .loaded(makeSnapshot()))
    }

    private let failure = HomeStateMessage(title: "failure", detail: nil, systemImageName: "wifi.slash")

    private func makeClient(result: HomeFetchResult) -> HomeClient {
        HomeClient(
            fetch: { result },
            failureMessage: HomeStateMessage(
                title: "failure",
                detail: nil,
                systemImageName: "wifi.slash"
            )
        )
    }

    private func makeSnapshot() -> HomeSnapshot {
        HomeSnapshot(nextEvent: nil, upcomingEvents: [])
    }
}

private enum StubError: Error {
    case failed
}

/// 呼ばれるたびに次の結果を返す。尽きたら失敗する（`recover()` の後は `thenReturn` を返し続ける）。
private final class ResultSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [HomeFetchResult]
    private let fallback: HomeFetchResult?
    private var recovered = false

    init(_ results: [HomeFetchResult], thenReturn fallback: HomeFetchResult? = nil) {
        self.results = results
        self.fallback = fallback
    }

    func recover() {
        lock.withLock { recovered = true }
    }

    func next() throws -> HomeFetchResult {
        try lock.withLock {
            if !results.isEmpty { return results.removeFirst() }
            if recovered, let fallback { return fallback }
            throw StubError.failed
        }
    }
}
