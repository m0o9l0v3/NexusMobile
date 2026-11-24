import XCTest
@testable import Nexus

@MainActor
final class AppRouterTests: XCTestCase {
    func testAppHasThreeTabsInDisplayOrder() {
        XCTAssertEqual(AppTab.allCases, [.home, .map, .guide])
    }

    func testHomeTabReselectionCancelsSearchButReturningFromMapKeepsIt() async {
        let classroom = TestSpots.classroom2A
        let model = AppShellModel(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [classroom]))
            }),
            mapContentClient: .unconfigured,
            mapSurface: .unavailable,
            guidanceClient: .unconfigured,
            routeHandler: .unconfigured
        )
        await model.coordinator().handle(.search(.focusedNewSearch), from: .home)
        let store = model.searchStore
        store.draftText = "2A"
        await store.updateHomeResults(for: "2A")
        await store.selectCategory(.classroom)
        let results = store.state

        model.selectTab(.map)
        model.selectTab(.map)
        model.selectTab(.home)

        XCTAssertTrue(store.isHomeSearchActive)
        XCTAssertEqual(store.phase, .results)
        XCTAssertEqual(store.committedQuery, SearchQuery(text: "2A", categoryID: .classroom))
        XCTAssertEqual(store.state, results)

        model.selectTab(.home)

        XCTAssertEqual(model.router.selectedTab, .home)
        XCTAssertFalse(store.isHomeSearchActive)
        XCTAssertEqual(store.committedQuery, .empty)
        XCTAssertEqual(store.state, .idle)
    }

    func testTabActivationPreservesEveryStackPath() {
        let router = AppRouter()
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "H")), on: .home)
        router.push(.allEvents, on: .map)
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "A")), on: .guide)

        router.activate(.map)
        router.activate(.map)
        router.activate(.guide)

        XCTAssertEqual(router.homePath, [.guidanceArticle(GuidanceArticleID(rawValue: "H"))])
        XCTAssertEqual(router.mapPath, [.allEvents])
        XCTAssertEqual(router.guidePath, [.guidanceArticle(GuidanceArticleID(rawValue: "A"))])
    }

    func testSelectedTabChangeDoesNotMutatePaths() {
        let router = AppRouter()
        for tab in AppTab.allCases {
            router.activate(tab)
        }
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.mapPath.isEmpty)
        XCTAssertTrue(router.guidePath.isEmpty)
    }

    func testPushAppliesToRequestedTabOnly() {
        let router = AppRouter()
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "reception")), on: .guide)

        XCTAssertEqual(router.guidePath.count, 1)
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.mapPath.isEmpty)
    }

    func testPopToRootDoesNotAffectOtherTabs() {
        let router = AppRouter()
        router.push(.allEvents, on: .home)
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "A")), on: .guide)

        router.popToRoot(of: .home)

        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertEqual(router.guidePath.count, 1)
    }
}
