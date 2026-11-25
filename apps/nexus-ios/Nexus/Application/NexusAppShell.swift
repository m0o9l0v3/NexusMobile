import SwiftUI

struct NexusAppShell: View {
    @State private var model: AppShellModel
    @State private var opensHomeSearchOnLaunch: Bool

    private let homeClient: HomeClient
    private let onRouteRequest: (AppRouteRequest) -> Void

    /// 新規パラメータはすべて既定値付き。既存の `NexusAppShell(homeClient:)` と
    /// `NexusAppShell(homeClient:onRouteRequest:)` はそのままコンパイルできる。
    init(
        homeClient: HomeClient,
        searchClient: SearchClient = .unconfigured,
        mapSearchClient: SearchClient? = nil,
        mapContentClient: MapContentClient = .unconfigured,
        mapSnapshotBoundary: MapSnapshotBoundary = .none,
        mapSurface: MapSurfaceProvider = .unavailable,
        guidanceClient: GuidanceClient = .unconfigured,
        routeHandler: RouteRequestHandling = .unconfigured,
        routeOriginClient: ManualRouteOriginClient = .unconfigured,
        eventListClient: EventListClient = .unconfigured,
        initialTab: AppTab = .home,
        opensHomeSearchOnLaunch: Bool = false,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil,
        initialRouteDestination: CanonicalSpotID? = nil,
        locationServices: LocationServices? = nil,
        onRouteRequest: @escaping (AppRouteRequest) -> Void = { _ in }
    ) {
        self.homeClient = homeClient
        _opensHomeSearchOnLaunch = State(initialValue: opensHomeSearchOnLaunch)
        self.onRouteRequest = onRouteRequest
        _model = State(
            wrappedValue: AppShellModel(
                searchClient: searchClient,
                mapSearchClient: mapSearchClient,
                mapContentClient: mapContentClient,
                mapSnapshotBoundary: mapSnapshotBoundary,
                mapSurface: mapSurface,
                guidanceClient: guidanceClient,
                routeHandler: routeHandler,
                routeOriginClient: routeOriginClient,
                eventListClient: eventListClient,
                initialTab: initialTab,
                initialGuidePath: initialGuidePath,
                initialMapSelection: initialMapSelection,
                initialRouteDestination: initialRouteDestination,
                locationServices: locationServices
            )
        )
    }

    var body: some View {
        @Bindable var router = model.router
        let guideShowsArticle = if case .guidanceArticle = router.guidePath.last { true } else { false }

        TabView(selection: Binding(get: { router.selectedTab }, set: model.selectTab)) {
            NavigationStack(path: $router.homePath) {
                HomeView(
                    client: homeClient,
                    searchStore: model.searchStore,
                    onRouteRequest: handler(from: .home)
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(
                        route: route,
                        guidanceStore: model.guidanceStore,
                        eventListClient: model.eventListClient
                    )
                }
            }
            // Home から push した画面（すべてのイベント）が遷移要求を送る経路。
            .environment(\.appRouteRequestHandler, handler(from: .home))
            .tabItem { tabLabel(AppTab.home) }
            .tag(AppTab.home)

            NavigationStack(path: $router.mapPath) {
                MapRootView(
                    store: model.mapStore,
                    searchStore: model.mapSearchStore,
                    routeStore: model.routeStore,
                    surface: model.mapSurface,
                    currentLocation: model.currentLocation,
                    routeOriginStore: model.routeOriginStore
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(
                        route: route,
                        guidanceStore: model.guidanceStore,
                        eventListClient: model.eventListClient
                    )
                }
            }
            .environment(\.appRouteRequestHandler, handler(from: .map))
            .tabItem { tabLabel(AppTab.map) }
            .tag(AppTab.map)

            NavigationStack(path: $router.guidePath) {
                GuidanceTopView(store: model.guidanceStore, routeStore: model.routeStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        AppDestinationView(
                            route: route,
                            guidanceStore: model.guidanceStore,
                            eventListClient: model.eventListClient
                        )
                    }
            }
            .toolbar(guideShowsArticle ? .hidden : .visible, for: .tabBar)
            .background {
                GuidanceTabBarTransition(isGuideSelected: router.selectedTab == .guide, showsArticle: guideShowsArticle)
            }
            .environment(\.appRouteRequestHandler, handler(from: .guide))
            .tabItem { tabLabel(AppTab.guide) }
            .tag(AppTab.guide)
        }
        .routePreviewSheet(model: model)
        .onReceive(NotificationCenter.default.publisher(for: .publishedBundleDisplayDidChange)) { _ in
            Task { await model.refreshBundleDisplay() }
        }
        .tint(.accentColor)
        .onChange(of: router.selectedTab) { oldTab, newTab in
            Task { await model.selectedTabChanged(from: oldTab, to: newTab) }
        }
        .task {
            if opensHomeSearchOnLaunch {
                opensHomeSearchOnLaunch = false
                await model.coordinator().handle(.search(.empty), from: .home)
            }
            // 起動時に選択地点が与えられていれば詳細を読み込む（比較用の初期状態）。
            if let selection = model.mapStore.selection,
               model.mapStore.detailState == .none {
                await model.mapStore.select(selection)
            }
            await model.requestInitialRouteIfNeeded()
        }
    }

    /// `AppRouteCoordinator.handle` は `async` だが、ボタンは同期。
    /// ここで `Task` に包む。テストは `handle` を直接呼ぶこと（スケジューリング非決定を避けるため）。
    private func handler(from origin: AppTab) -> (AppRouteRequest) -> Void {
        { request in
            Task { @MainActor in
                await model.coordinator(observer: { request, _ in onRouteRequest(request) })
                    .handle(request, from: origin)
            }
        }
    }

    @ViewBuilder
    private func tabLabel(_ tab: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            if let assetImageName = tab.assetImageName {
                Image(assetImageName)
                    .renderingMode(.template)
            } else {
                Image(systemName: tab.systemImageName)
            }
        }
    }
}
