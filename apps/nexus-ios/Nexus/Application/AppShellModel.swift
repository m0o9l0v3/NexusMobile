import Foundation

/// 合成ルート。タブをまたいで使うストアを保持する。
/// グローバル singleton は作らず、`NexusAppShell` の `@State` として1回だけ生成する。
@MainActor
@Observable
final class AppShellModel {
    let router: AppRouter
    let searchHistory: SearchHistoryStore
    /// Home のインライン検索状態。
    let searchStore: SearchStore
    /// Map の検索オーバーレイの検索状態。
    /// Home と別インスタンスにして、互いの検索条件を保持する。
    /// 検索履歴（`searchHistory`）は共有する。
    let mapSearchStore: SearchStore
    let mapStore: MapStore
    let guidanceStore: GuidanceStore
    let routeStore: RouteRequestStore
    let routeOriginStore: ManualRouteOriginStore
    private(set) var initialRouteDestination: CanonicalSpotID?
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
        routeOriginClient: ManualRouteOriginClient = .unconfigured,
        eventListClient: EventListClient = .unconfigured,
        initialTab: AppTab = .home,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil,
        initialRouteDestination: CanonicalSpotID? = nil,
        locationServices: LocationServices? = nil
    ) {
        let history = SearchHistoryStore()
        self.router = AppRouter(selectedTab: initialTab, guidePath: initialGuidePath)
        self.searchHistory = history
        self.searchStore = SearchStore(client: searchClient, history: history, surface: .home)
        // Map の検索は、Map が固定した版（M1-7）から読む。指定がなければ Home と同じ Client。
        let mapSearchStore = SearchStore(client: mapSearchClient ?? searchClient, history: history, surface: .map)
        self.mapSearchStore = mapSearchStore
        let routeStore = RouteRequestStore(handler: routeHandler)
        let routeOriginStore = ManualRouteOriginStore(client: routeOriginClient, routeStore: routeStore)
        self.routeStore = routeStore
        self.routeOriginStore = routeOriginStore
        self.mapStore = MapStore(
            client: mapContentClient,
            snapshotBoundary: mapSnapshotBoundary,
            overlaySearch: mapSearchStore,
            initialSelection: initialMapSelection,
            allowsSnapshotUpdate: { !routeStore.keepsMapSnapshot && !routeOriginStore.isPresenting }
        )
        self.guidanceStore = GuidanceStore(client: guidanceClient)
        self.initialRouteDestination = initialRouteDestination
        self.mapSurface = mapSurface
        self.eventListClient = eventListClient
        let location = locationServices ?? .live()
        self.currentLocation = CurrentLocationStore(
            permission: LocationPermissionStore(provider: location.permission),
            updates: location.updates,
            settings: location.settings
        )
        currentLocation.permission.onChooseStartManually = { [weak self] in
            Task { @MainActor [weak self] in await self?.chooseManualOriginFromLocationGuidance() }
        }
    }

    func chooseManualOriginFromLocationGuidance() async {
        if let id = mapStore.selection?.canonicalSpotID {
            await routeOriginStore.beginSelection(for: id, from: .map)
        } else if routeStore.activeDestination != nil {
            await routeOriginStore.beginOriginChangeForActiveRoute()
        } else if routeStore.lastOutcome?.allowsOriginSelectionRetry == true {
            await routeOriginStore.beginOriginRetryForLastAttempt()
        } else {
            mapStore.isSearchActive = true
        }
    }

    func requestInitialRouteIfNeeded() async {
        guard let destination = initialRouteDestination else { return }
        initialRouteDestination = nil
        await routeStore.requestRoute(to: destination, from: .map)
    }

    /// TabView の利用者操作だけを受け取る。別タブから Home を開くと、検索を再表示する。
    func selectTab(_ tab: AppTab) {
        if router.selectedTab == .home {
            if tab == .home {
                searchStore.cancelHomeSearch()
            } else {
                searchStore.endEditing()
            }
        }
        router.activate(tab)
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
