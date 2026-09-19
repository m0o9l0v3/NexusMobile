import Foundation

/// 合成ルート。`let` 参照だけを持ち、自前の状態は持たない。
/// グローバル singleton は作らず、`NexusAppShell` の `@State` として1回だけ生成する。
@MainActor
@Observable
final class AppShellModel {
    let router: AppRouter
    let searchHistory: SearchHistoryStore
    /// 探すタブの検索状態。
    let searchStore: SearchStore
    /// Map の検索オーバーレイの検索状態。
    /// 探すと別インスタンスにするのは、Map で打鍵しても探すの確定条件を書き換えないため。
    /// 検索履歴（`searchHistory`）は共有する。
    let mapSearchStore: SearchStore
    let mapStore: MapStore
    let guidanceStore: GuidanceStore
    let routeStore: RouteRequestStore
    let mapSurface: MapSurfaceProvider

    /// `initialTab` / `initialGuidePath` は `HomeView(initialState:)` と同じ趣旨の
    /// 合成用パラメータ。Preview とシミュレーターでの Figma 比較に使う。
    init(
        searchClient: SearchClient,
        mapContentClient: MapContentClient,
        mapSurface: MapSurfaceProvider,
        guidanceClient: GuidanceClient,
        routeHandler: RouteRequestHandling,
        initialTab: AppTab = .home,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil
    ) {
        let history = SearchHistoryStore()
        self.router = AppRouter(selectedTab: initialTab, guidePath: initialGuidePath)
        self.searchHistory = history
        self.searchStore = SearchStore(client: searchClient, history: history, surface: .search)
        self.mapSearchStore = SearchStore(client: searchClient, history: history, surface: .map)
        self.mapStore = MapStore(client: mapContentClient, initialSelection: initialMapSelection)
        self.guidanceStore = GuidanceStore(client: guidanceClient)
        self.routeStore = RouteRequestStore(handler: routeHandler)
        self.mapSurface = mapSurface
    }

    func coordinator(
        observer: @escaping (AppRouteRequest, AppTab) -> Void = { _, _ in }
    ) -> AppRouteCoordinator {
        AppRouteCoordinator(
            router: router,
            searchStore: searchStore,
            mapStore: mapStore,
            guidanceStore: guidanceStore,
            routeStore: routeStore,
            observer: observer
        )
    }
}
