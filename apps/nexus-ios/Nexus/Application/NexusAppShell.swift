import SwiftUI

struct NexusAppShell: View {
    @State private var model: AppShellModel

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
        eventListClient: EventListClient = .unconfigured,
        initialTab: AppTab = .home,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil,
        locationServices: LocationServices? = nil,
        onRouteRequest: @escaping (AppRouteRequest) -> Void = { _ in }
    ) {
        self.homeClient = homeClient
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
                eventListClient: eventListClient,
                initialTab: initialTab,
                initialGuidePath: initialGuidePath,
                initialMapSelection: initialMapSelection,
                locationServices: locationServices
            )
        )
    }

    var body: some View {
        @Bindable var router = model.router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView(
                    client: homeClient,
                    routeStore: model.routeStore,
                    onRouteRequest: handler(from: .home)
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(
                        route: route,
                        guidanceStore: model.guidanceStore,
                        eventListClient: model.eventListClient,
                        routeStore: model.routeStore
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
                    currentLocation: model.currentLocation
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(
                        route: route,
                        guidanceStore: model.guidanceStore,
                        eventListClient: model.eventListClient,
                        routeStore: model.routeStore
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
                            eventListClient: model.eventListClient,
                            routeStore: model.routeStore
                        )
                    }
            }
            .environment(\.appRouteRequestHandler, handler(from: .guide))
            .tabItem { tabLabel(AppTab.guide) }
            .tag(AppTab.guide)

            NavigationStack(path: $router.searchPath) {
                SearchRootView(store: model.searchStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        AppDestinationView(
                            route: route,
                            guidanceStore: model.guidanceStore,
                            eventListClient: model.eventListClient,
                            routeStore: model.routeStore
                        )
                    }
            }
            .environment(\.appRouteRequestHandler, handler(from: .search))
            .tabItem { tabLabel(AppTab.search) }
            .tag(AppTab.search)
        }
        .tint(.accentColor)
        .onChange(of: router.selectedTab) { oldTab, newTab in
            Task { await model.selectedTabChanged(from: oldTab, to: newTab) }
        }
        .task {
            // 起動時に選択地点が与えられていれば詳細を読み込む（比較用の初期状態）。
            if let selection = model.mapStore.selection,
               model.mapStore.detailState == .none {
                await model.mapStore.select(selection)
            }
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
