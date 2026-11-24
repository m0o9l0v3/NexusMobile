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

    func loadRoutePreview(id: UUID, currentFix: LocationFix?, manualOrigin: RouteOrigin?) async {
        await mapStore.waitForSnapshotUpdate()
        await routeStore.loadPreview(id: id, currentFix: currentFix, manualOrigin: manualOrigin)
    }

    func startPreviewedRoute(id: UUID) {
        guard routeStore.startPreviewedRoute(id: id) else { return }
        mapStore.dismissDetailForRoute()
        mapStore.isSearchActive = false
        router.activate(.map)
    }

    func handle(_ request: AppRouteRequest, from origin: AppTab) async {
        observer(request, origin)

        switch request {
        case .search(let searchRequest):
            router.popToRoot(of: .home)
            router.activate(.home)
            await searchStore.apply(searchRequest)

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

        case .routePreview(let target):
            routeStore.presentPreview(for: target, from: origin)

        case .route(let destinationSpotID):
            // 案内記事など、タブ内で結果を知らせる既存の要求。
            await routeStore.requestRoute(to: destinationSpotID, from: origin)

        case .guidanceTop:
            router.activate(.guide)

        case .guidanceArticle(let articleID):
            router.activate(.guide)
            router.push(.guidanceArticle(articleID), on: .guide)

        case .allEvents:
            router.push(.allEvents, on: origin)
        }
    }
}
