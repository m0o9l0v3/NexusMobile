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
    /// 「すべてのイベント」の取得元。画面を開くたびに新しい Store を作る。
    let eventListClient: EventListClient
    /// Map の現在地（#29）。権限は `currentLocation.permission`（#25）。
    let currentLocation: CurrentLocationStore

    /// `initialTab` / `initialGuidePath` は `HomeView(initialState:)` と同じ趣旨の
    /// 合成用パラメータ。Preview とシミュレーターでの Figma 比較に使う。
    init(
        searchClient: SearchClient,
        mapSearchClient: SearchClient? = nil,
        mapContentClient: MapContentClient,
        mapSnapshotBoundary: MapSnapshotBoundary = .none,
        mapSurface: MapSurfaceProvider,
        guidanceClient: GuidanceClient,
        routeHandler: RouteRequestHandling,
        eventListClient: EventListClient = .unconfigured,
        initialTab: AppTab = .home,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil,
        locationServices: LocationServices? = nil
    ) {
        let history = SearchHistoryStore()
        self.router = AppRouter(selectedTab: initialTab, guidePath: initialGuidePath)
        self.searchHistory = history
        self.searchStore = SearchStore(client: searchClient, history: history, surface: .search)
        // Map の検索は、Map が固定した版（M1-7）から読む。指定がなければ探すと同じ Client。
        let mapSearchStore = SearchStore(client: mapSearchClient ?? searchClient, history: history, surface: .map)
        self.mapSearchStore = mapSearchStore
        self.mapStore = MapStore(
            client: mapContentClient,
            snapshotBoundary: mapSnapshotBoundary,
            overlaySearch: mapSearchStore,
            initialSelection: initialMapSelection
        )
        self.guidanceStore = GuidanceStore(client: guidanceClient)
        self.routeStore = RouteRequestStore(handler: routeHandler)
        self.mapSurface = mapSurface
        self.eventListClient = eventListClient
        let location = locationServices ?? .live()
        self.currentLocation = CurrentLocationStore(
            permission: LocationPermissionStore(provider: location.permission),
            updates: location.updates,
            settings: location.settings
        )
    }

    /// タブの切替を受け取る。Map タブを開き直したときが版の切替点になる（M1-7）。
    func selectedTabChanged(from oldTab: AppTab, to newTab: AppTab) async {
        guard newTab == .map, oldTab != .map else { return }
        await mapStore.mapTabDidOpen()
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
