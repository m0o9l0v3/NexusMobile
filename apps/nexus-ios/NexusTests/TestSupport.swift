import XCTest
@testable import Nexus

/// テスト専用のスタブ。Preview fixture とは独立に持ち、
/// fixture の変更でテストの期待値が動かないようにする。
enum TestStubError: Error {
    case simulated
}

@MainActor
enum TestSpots {
    static let classroom2A = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
        displayName: "2A教室",
        kind: .classroom,
        buildingName: "教室棟",
        floorName: "2F"
    )

    /// 大文字混じり。小文字形とは**別の地点**として扱われなければならない。
    static let classroom2AUpperCase = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "Mb_F2_CR_2A"),
        displayName: "2A教室（別表記）",
        kind: .classroom,
        buildingName: "教室棟",
        floorName: "2F"
    )

    static let hangarA = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "hgr_a"),
        displayName: "格納庫A",
        kind: .facility,
        buildingName: "構内"
    )
}

extension NexusStateMessage {
    static let testFailure = NexusStateMessage(
        title: "テスト用の失敗",
        detail: nil,
        systemImageName: "xmark"
    )
}

extension SearchClient {
    static func stub(
        initial: @escaping @Sendable () async throws -> SearchInitialFetchResult = {
            .fresh(SearchInitialSnapshot(headingText: "すべての地点", spots: []))
        },
        search: @escaping @Sendable (SearchQuery) async throws -> SearchFetchResult = { query in
            .fresh(SearchResultsSnapshot(query: query, spots: []))
        }
    ) -> SearchClient {
        SearchClient(initialContent: initial, search: search, failureMessage: .testFailure)
    }
}

extension MapContentClient {
    static func stub(
        spotDetail: @escaping @Sendable (CanonicalSpotID) async throws -> SpotDetailFetchResult
    ) -> MapContentClient {
        MapContentClient(spotDetail: spotDetail, failureMessage: .testFailure)
    }
}

extension GuidanceClient {
    static func stub(
        top: @escaping @Sendable () async throws -> GuidanceTopFetchResult = {
            .fresh(GuidanceTopSnapshot(updateStatus: .normal))
        },
        article: @escaping @Sendable (GuidanceArticleID) async throws -> GuidanceArticleFetchResult
    ) -> GuidanceClient {
        GuidanceClient(fetchTop: top, fetchArticle: article, failureMessage: .testFailure)
    }
}

@MainActor
struct TestHarness {
    let router: AppRouter
    let history: SearchHistoryStore
    let searchStore: SearchStore
    let mapSearchStore: SearchStore
    let mapStore: MapStore
    let guidanceStore: GuidanceStore
    let routeStore: RouteRequestStore
    let coordinator: AppRouteCoordinator

    init(
        searchClient: SearchClient = .stub(),
        mapContentClient: MapContentClient = .stub(spotDetail: { .unknownSpot($0) }),
        guidanceClient: GuidanceClient = .stub(article: { .notProvided($0) }),
        routeHandler: RouteRequestHandling = .unconfigured
    ) {
        let history = SearchHistoryStore()
        self.router = AppRouter()
        self.history = history
        self.searchStore = SearchStore(client: searchClient, history: history, surface: .search)
        self.mapSearchStore = SearchStore(client: searchClient, history: history, surface: .map)
        self.mapStore = MapStore(client: mapContentClient)
        self.guidanceStore = GuidanceStore(client: guidanceClient)
        self.routeStore = RouteRequestStore(handler: routeHandler)
        self.coordinator = AppRouteCoordinator(
            router: router,
            searchStore: searchStore,
            mapStore: mapStore,
            guidanceStore: guidanceStore,
            routeStore: routeStore
        )
    }

    /// `handle` を直接 await する。View の `Task { }` ラッパーを経由すると
    /// スケジューリングが非決定になりテストがフレーキーになる。
    func handle(_ request: AppRouteRequest, from origin: AppTab) async {
        await coordinator.handle(request, from: origin)
    }
}

/// 経路要求を常に受理するハンドラ。
extension RouteRequestHandling {
    static let alwaysAccepting = RouteRequestHandling { canonicalSpotID, tab in
        .accepted(RouteDestination(canonicalSpotID: canonicalSpotID, requestedFrom: tab))
    }

    static func rejecting(_ outcome: @escaping @Sendable (CanonicalSpotID) -> RouteRequestOutcome)
        -> RouteRequestHandling
    {
        RouteRequestHandling { canonicalSpotID, _ in outcome(canonicalSpotID) }
    }
}
