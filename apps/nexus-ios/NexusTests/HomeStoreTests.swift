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
        HomeSnapshot(nextEvent: nil, announcements: [], featuredEvents: [])
    }
}

private enum StubError: Error {
    case failed
}
