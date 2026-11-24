import XCTest
@testable import Nexus

@MainActor
final class AppRouteCoordinatorTests: XCTestCase {

    // MARK: - Home 内の検索

    func testHomeSearchEntryOpensInlineAndFocusesInput() async {
        let harness = TestHarness()

        await harness.handle(.search(.focusedNewSearch), from: .home)

        XCTAssertEqual(harness.router.selectedTab, .home)
        XCTAssertTrue(harness.searchStore.isHomeSearchActive)
        XCTAssertEqual(harness.searchStore.phase, .focused)
        XCTAssertEqual(harness.searchStore.committedQuery, .empty)
    }

    func testHomeCategoryEntryAppliesConditionWithoutFocusingInput() async {
        let harness = TestHarness(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.hangarA]))
            })
        )

        harness.router.activate(.map)
        harness.router.push(.allEvents, on: .home)
        let request = HomeSearchRequest(query: nil, categoryID: "facility")
        await harness.handle(.search(request), from: .map)

        XCTAssertTrue(harness.router.homePath.isEmpty)

        XCTAssertEqual(harness.router.selectedTab, .home)
        XCTAssertTrue(harness.searchStore.isHomeSearchActive)
        XCTAssertEqual(harness.searchStore.phase, .results)
        XCTAssertEqual(harness.searchStore.committedQuery.categoryID, .facility)
        XCTAssertFalse(request.intent.focusesInput)
        XCTAssertNil(harness.searchStore.unresolvedCategoryID)
    }

    func testUnknownCategoryFallsBackToAllAndRecordsUnresolvedValue() async {
        let harness = TestHarness(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            })
        )

        await harness.handle(
            .search(HomeSearchRequest(query: "2A", categoryID: "unknown_cat")),
            from: .home
        )

        XCTAssertNil(harness.searchStore.committedQuery.categoryID)
        XCTAssertEqual(harness.searchStore.unresolvedCategoryID, "unknown_cat")
    }

    // MARK: - Home 検索 → Map（canonical ID の受け渡し）

    func testSearchResultHandOffCarriesIdenticalCanonicalID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) })
        )

        await harness.handle(
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .home
        )

        XCTAssertEqual(harness.router.selectedTab, .map)
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_2f_cl_001")
        XCTAssertEqual(harness.mapStore.selection?.origin, .home)
    }

    func testSpotHandOffPreservesCaseSensitiveIdentifier() async {
        let received = SendableBox<CanonicalSpotID?>(nil)
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { id in
                await received.set(id)
                return .fresh(SpotDetailPresentation(summary: TestSpots.classroom2AUpperCase))
            })
        )

        await harness.handle(
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "Mb_2F_CL_001")),
            from: .home
        )

        let value = await received.get()
        XCTAssertEqual(value?.rawValue, "Mb_2F_CL_001")
        XCTAssertNotEqual(value, CanonicalSpotID(rawValue: "mb_2f_cl_001"))
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "Mb_2F_CL_001")
    }

    func testHomeEventDetailsCarriesEventIDAlongsideSpotID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) })
        )

        await harness.handle(
            .eventDetails(
                eventID: "PREVIEW_EVENT_DRONE",
                canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")
            ),
            from: .home
        )

        XCTAssertEqual(harness.mapStore.selection?.eventID, "PREVIEW_EVENT_DRONE")
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_2f_cl_001")
    }

    // MARK: - 経路要求

    func testHomeEventRouteRequestSetsDestinationWithoutChangingMapSelection() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .home
        )

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "mb_2f_cl_001")
        XCTAssertNil(harness.mapStore.selection)
    }

    /// 地点を閲覧しただけで進行中の案内先が変わらない（#85 M14）。
    func testViewingSpotDoesNotChangeActiveRouteDestination() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.hangarA)) }),
            routeHandler: .alwaysAccepting
        )

        await harness.handle(.route(destinationSpotID: CanonicalSpotID(rawValue: "spot_a")), from: .home)
        await harness.handle(.spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "spot_b")), from: .home)

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "spot_a")
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "spot_b")
    }

    func testRouteRequestDoesNotSwitchTabs() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)
        harness.router.activate(.guide)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .guide
        )

        XCTAssertEqual(harness.router.selectedTab, .guide)
    }

    func testMapSpotDetailRouteRequestUsesSelectedSpotID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) }),
            routeHandler: .alwaysAccepting
        )

        await harness.handle(
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .home
        )
        let selected = harness.mapStore.selection!.canonicalSpotID
        await harness.handle(.route(destinationSpotID: selected), from: .map)

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID, selected)
        XCTAssertEqual(harness.routeStore.activeDestination?.requestedFrom, .map)
    }

    // MARK: - 案内

    func testGuidanceArticleRequestActivatesGuideTabAndPushesArticle() async {
        let harness = TestHarness()
        let articleID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_RECEPTION")

        await harness.handle(.guidanceArticle(articleID: articleID), from: .home)

        XCTAssertEqual(harness.router.selectedTab, .guide)
        XCTAssertEqual(harness.router.guidePath, [.guidanceArticle(articleID)])
    }

    func testGuidanceRelatedPlaceHandOffUsesArticleCanonicalID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) })
        )

        await harness.handle(
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .guide
        )

        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_2f_cl_001")
        XCTAssertEqual(harness.mapStore.selection?.origin, .guide)
    }

    func testGuidanceRouteRequestUsesRelatedPlaceCanonicalID() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")),
            from: .guide
        )

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "mb_2f_cl_001")
        XCTAssertEqual(harness.routeStore.activeDestination?.requestedFrom, .guide)
    }

    // MARK: - すべてのイベント

    func testAllEventsPushesTheEventListOnTheOriginTab() async {
        let harness = TestHarness()

        await harness.handle(.allEvents, from: .home)

        XCTAssertEqual(harness.router.homePath, [.allEvents])
        XCTAssertTrue(harness.router.mapPath.isEmpty)
        XCTAssertTrue(harness.router.guidePath.isEmpty)
    }

    // MARK: - 状態の保持

    func testHandlingRequestsDoesNotClearHomeSearchOrOtherTabPath() async {
        let harness = TestHarness(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            }),
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) }),
            routeHandler: .alwaysAccepting
        )

        await harness.handle(.search(.focusedNewSearch), from: .home)
        harness.searchStore.draftText = "2A"
        await harness.searchStore.updateHomeResults(for: "2A")
        await harness.searchStore.selectCategory(.classroom)
        harness.router.push(.allEvents, on: .guide)

        let committedBefore = harness.searchStore.committedQuery
        let resultsBefore = harness.searchStore.state

        await harness.handle(.spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")), from: .home)
        await harness.handle(.route(destinationSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001")), from: .map)
        await harness.handle(.guidanceTop, from: .map)
        harness.router.activate(.home)

        XCTAssertTrue(harness.searchStore.isHomeSearchActive)
        XCTAssertEqual(harness.searchStore.draftText, "2A")
        XCTAssertEqual(harness.searchStore.committedQuery, committedBefore)
        XCTAssertEqual(harness.searchStore.state, resultsBefore)
        XCTAssertEqual(harness.router.guidePath, [.allEvents])
    }
}

/// `@Sendable` クロージャから値を回収するための最小限の箱。
actor SendableBox<Value: Sendable> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func set(_ newValue: Value) {
        value = newValue
    }

    func get() -> Value {
        value
    }
}
