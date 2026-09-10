import Foundation

/// 遷移要求をタブ・スタック・各ストアの変更へ写す唯一の場所。
///
/// 自身は状態を持たない。すべての判断がこの1ファイルに集まるので、
/// 「タブ切替やハンドオフで何が保持され何が変わるか」を単体テストで固定できる。
@MainActor
struct AppRouteCoordinator {
    let router: AppRouter
    let searchStore: SearchStore
    let mapStore: MapStore
    let guidanceStore: GuidanceStore
    let routeStore: RouteRequestStore
    /// 観測用の副次チャネル。`NexusAppShell` の既存 `onRouteRequest` を受ける。
    var observer: (AppRouteRequest, AppTab) -> Void = { _, _ in }

    init(
        router: AppRouter,
        searchStore: SearchStore,
        mapStore: MapStore,
        guidanceStore: GuidanceStore,
        routeStore: RouteRequestStore,
        observer: @escaping (AppRouteRequest, AppTab) -> Void = { _, _ in }
    ) {
        self.router = router
        self.searchStore = searchStore
        self.mapStore = mapStore
        self.guidanceStore = guidanceStore
        self.routeStore = routeStore
        self.observer = observer
    }

    func handle(_ request: AppRouteRequest, from origin: AppTab) async {
        observer(request, origin)

        switch request {
        case .search(let searchRequest):
            await searchStore.apply(searchRequest)
            router.activate(.search)

        case .spotDetails(let canonicalSpotID):
            await mapStore.select(
                MapSelection(canonicalSpotID: canonicalSpotID, eventID: nil, origin: origin)
            )
            router.activate(.map)

        case .eventDetails(let eventID, let canonicalSpotID):
            await mapStore.select(
                MapSelection(canonicalSpotID: canonicalSpotID, eventID: eventID, origin: origin)
            )
            router.activate(.map)

        case .route(let destinationSpotID):
            // タブは切り替えない。経路確認画面は Figma に存在せず、経路探索も範囲外のため、
            // 利用者が求めていないプレースホルダへ飛ばさない。結果は現在のタブ内で通知する。
            await routeStore.requestRoute(to: destinationSpotID, from: origin)

        case .guidanceTop:
            router.activate(.guide)

        case .guidanceArticle(let articleID):
            router.activate(.guide)
            router.push(.guidanceArticle(articleID), on: .guide)

        case .allAnnouncements:
            router.push(.notProvided(.announcementList), on: origin)

        case .announcementDetails:
            router.push(.notProvided(.announcementDetail), on: origin)

        case .allEvents:
            router.push(.notProvided(.eventList), on: origin)
        }
    }
}
