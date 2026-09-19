import XCTest
@testable import Nexus

@MainActor
final class AppRouteCoordinatorTests: XCTestCase {

    // MARK: - Home → 探す

    func testHomeSearchEntryActivatesSearchTabAndFocusesInput() async {
        let harness = TestHarness()

        await harness.handle(.search(.focusedNewSearch), from: .home)

        XCTAssertEqual(harness.router.selectedTab, .search)
        XCTAssertEqual(harness.searchStore.phase, .focused)
        XCTAssertEqual(harness.searchStore.committedQuery, .empty)
    }

    func testHomeCategoryEntryAppliesConditionWithoutFocusingInput() async {
        let harness = TestHarness(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.hangarA]))
            })
        )

        let request = HomeSearchRequest(query: nil, categoryID: "facility")
        await harness.handle(.search(request), from: .home)

        XCTAssertEqual(harness.router.selectedTab, .search)
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

    // MARK: - 探す → Map（canonical ID の受け渡し）

    func testSearchResultHandOffCarriesIdenticalCanonicalID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) })
        )

        await harness.handle(
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
            from: .search
        )

        XCTAssertEqual(harness.router.selectedTab, .map)
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertEqual(harness.mapStore.selection?.origin, .search)
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
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "Mb_F2_CR_2A")),
            from: .search
        )

        let value = await received.get()
        XCTAssertEqual(value?.rawValue, "Mb_F2_CR_2A")
        XCTAssertNotEqual(value, CanonicalSpotID(rawValue: "mb_f2_cr_2a"))
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "Mb_F2_CR_2A")
    }

    func testHomeEventDetailsCarriesEventIDAlongsideSpotID() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) })
        )

        await harness.handle(
            .eventDetails(
                eventID: "PREVIEW_EVENT_DRONE",
                canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")
            ),
            from: .home
        )

        XCTAssertEqual(harness.mapStore.selection?.eventID, "PREVIEW_EVENT_DRONE")
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
    }

    // MARK: - 経路要求

    func testHomeEventRouteRequestSetsDestinationWithoutChangingMapSelection() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
            from: .home
        )

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertNil(harness.mapStore.selection)
    }

    /// 地点を閲覧しただけで進行中の案内先が変わらない（#85 M14）。
    func testViewingSpotDoesNotChangeActiveRouteDestination() async {
        let harness = TestHarness(
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.hangarA)) }),
            routeHandler: .alwaysAccepting
        )

        await harness.handle(.route(destinationSpotID: CanonicalSpotID(rawValue: "spot_a")), from: .home)
        await harness.handle(.spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "spot_b")), from: .search)

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "spot_a")
        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "spot_b")
    }

    func testRouteRequestDoesNotSwitchTabs() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)
        harness.router.activate(.guide)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
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
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
            from: .search
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
            .spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
            from: .guide
        )

        XCTAssertEqual(harness.mapStore.selection?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertEqual(harness.mapStore.selection?.origin, .guide)
    }

    func testGuidanceRouteRequestUsesRelatedPlaceCanonicalID() async {
        let harness = TestHarness(routeHandler: .alwaysAccepting)

        await harness.handle(
            .route(destinationSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")),
            from: .guide
        )

        XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertEqual(harness.routeStore.activeDestination?.requestedFrom, .guide)
    }

    // MARK: - 未設計画面

    func testUndesignedScreensPushExplicitNotProvidedRoute() async {
        let harness = TestHarness()

        await harness.handle(.allAnnouncements, from: .home)
        await harness.handle(
            .announcementDetails(id: "a1", canonicalSpotID: nil),
            from: .home
        )
        await harness.handle(.allEvents, from: .home)

        XCTAssertEqual(
            harness.router.homePath,
            [
                .notProvided(.announcementList),
                .notProvided(.announcementDetail),
                .notProvided(.eventList),
            ]
        )
        XCTAssertTrue(harness.router.mapPath.isEmpty)
        XCTAssertTrue(harness.router.guidePath.isEmpty)
        XCTAssertTrue(harness.router.searchPath.isEmpty)
    }

    // MARK: - 状態の保持

    func testHandlingRequestsDoesNotClearSearchConditionsOrSearchPath() async {
        let harness = TestHarness(
            searchClient: .stub(search: { query in
                .fresh(SearchResultsSnapshot(query: query, spots: [TestSpots.classroom2A]))
            }),
            mapContentClient: .stub(spotDetail: { _ in .fresh(SpotDetailPresentation(summary: TestSpots.classroom2A)) }),
            routeHandler: .alwaysAccepting
        )

        harness.searchStore.draftText = "2A"
        await harness.searchStore.submit()
        harness.router.push(.notProvided(.eventList), on: .search)

        let committedBefore = harness.searchStore.committedQuery
        let searchPathBefore = harness.router.searchPath

        await harness.handle(.spotDetails(canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")), from: .search)
        await harness.handle(.route(destinationSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")), from: .map)
        await harness.handle(.guidanceTop, from: .map)
        await harness.handle(.allEvents, from: .home)

        XCTAssertEqual(harness.searchStore.committedQuery, committedBefore)
        XCTAssertEqual(harness.router.searchPath, searchPathBefore)
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
