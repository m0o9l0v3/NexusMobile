import XCTest
@testable import Nexus

@MainActor
final class EventListStoreTests: XCTestCase {
    private let failure = HomeStateMessage(title: "failure", detail: nil, systemImageName: "wifi.slash")

    private func slot(_ id: String, category: String?) -> EventListSlot {
        EventListSlot(
            id: id, eventID: "e-\(id)", canonicalSpotID: CanonicalSpotID(rawValue: "spot"),
            categoryID: category, categoryName: category, title: id, startText: "10:00", endText: "11:00",
            modeText: nil, locationName: "venue", isCancelled: false, cancelNote: nil
        )
    }

    private func snapshot(categories: [String] = ["A", "B"]) -> EventListSnapshot {
        EventListSnapshot(
            days: [EventListDay(id: "2027-08-01", title: "8月1日（日）", isToday: true, slots: [
                slot("1", category: "A"), slot("2", category: "B"), slot("3", category: nil),
            ])],
            categories: categories.map { EventListCategory(id: $0, name: $0) }
        )
    }

    private func client(_ results: [Result<EventListFetchResult, Error>]) -> EventListClient {
        let sequence = Sequence(results)
        return EventListClient(fetch: { try sequence.next() }, failureMessage: failure)
    }

    func testFreshBecomesLoaded() async {
        let store = EventListStore(client: client([.success(.fresh(snapshot()))]))
        await store.refresh()
        XCTAssertEqual(store.state, .loaded(snapshot()))
        XCTAssertEqual(store.visibleDays.flatMap(\.slots).map(\.id), ["1", "2", "3"])
    }

    func testEmptyStaysDistinctFromFailure() async {
        let store = EventListStore(client: client([.success(.empty(EventListClient.noEventsMessage))]))
        await store.refresh()
        XCTAssertEqual(store.state, .empty(EventListClient.noEventsMessage))
        XCTAssertEqual(store.visibleDays, [])
    }

    func testSavedCarriesMetadata() async {
        let metadata = SavedHomeMetadata(title: "saved", detail: nil)
        let store = EventListStore(client: client([.success(.saved(snapshot(), metadata))]))
        await store.refresh()
        XCTAssertEqual(store.state, .saved(snapshot(), metadata))
        XCTAssertEqual(store.visibleDays.count, 1)
    }

    func testFailureUsesConfiguredMessageAndRetryLoads() async {
        let store = EventListStore(client: client([.failure(StubError.failed), .success(.fresh(snapshot()))]))
        await store.refresh()
        XCTAssertEqual(store.state, .failed(failure))
        await store.retry()
        XCTAssertEqual(store.state, .loaded(snapshot()))
    }

    func testFailedRefreshKeepsShownContent() async {
        let store = EventListStore(client: client([.success(.fresh(snapshot())), .failure(StubError.failed)]))
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(store.state, .loaded(snapshot()))
    }

    func testCategorySelectionFiltersVisibleDays() async {
        let store = EventListStore(client: client([.success(.fresh(snapshot()))]))
        await store.refresh()

        store.selectedCategoryID = "B"
        XCTAssertEqual(store.visibleDays.flatMap(\.slots).map(\.id), ["2"])
        store.selectedCategoryID = nil
        XCTAssertEqual(store.visibleDays.flatMap(\.slots).map(\.id), ["1", "2", "3"])
    }

    /// 新しい版で選んでいたカテゴリが消えたら「すべて」に戻す。
    func testSelectionResetsWhenCategoryDisappears() async {
        let store = EventListStore(client: client([
            .success(.fresh(snapshot())),
            .success(.fresh(snapshot(categories: ["A"]))),
        ]))
        await store.refresh()
        store.selectedCategoryID = "B"
        await store.refresh()
        XCTAssertNil(store.selectedCategoryID)
    }

    func testSelectionSurvivesRefreshWhenCategoryRemains() async {
        let store = EventListStore(client: client([.success(.fresh(snapshot())), .success(.fresh(snapshot()))]))
        await store.refresh()
        store.selectedCategoryID = "A"
        await store.refresh()
        XCTAssertEqual(store.selectedCategoryID, "A")
    }
}

private enum StubError: Error {
    case failed
}

private final class Sequence: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<EventListFetchResult, Error>]

    init(_ results: [Result<EventListFetchResult, Error>]) {
        self.results = results
    }

    func next() throws -> EventListFetchResult {
        try lock.withLock {
            guard !results.isEmpty else { throw StubError.failed }
            return try results.removeFirst().get()
        }
    }
}
