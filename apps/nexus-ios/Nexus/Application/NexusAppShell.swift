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
        mapContentClient: MapContentClient = .unconfigured,
        mapSurface: MapSurfaceProvider = .unavailable,
        guidanceClient: GuidanceClient = .unconfigured,
        routeHandler: RouteRequestHandling = .unconfigured,
        initialTab: AppTab = .home,
        initialGuidePath: [AppRoute] = [],
        initialMapSelection: MapSelection? = nil,
        onRouteRequest: @escaping (AppRouteRequest) -> Void = { _ in }
    ) {
        self.homeClient = homeClient
        self.onRouteRequest = onRouteRequest
        _model = State(
            wrappedValue: AppShellModel(
                searchClient: searchClient,
                mapContentClient: mapContentClient,
                mapSurface: mapSurface,
                guidanceClient: guidanceClient,
                routeHandler: routeHandler,
                initialTab: initialTab,
                initialGuidePath: initialGuidePath,
                initialMapSelection: initialMapSelection
            )
        )
    }

    var body: some View {
        @Bindable var router = model.router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView(
                    client: homeClient,
                    onRouteRequest: handler(from: .home)
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(route: route, guidanceStore: model.guidanceStore)
                }
            }
            .tabItem { tabLabel(AppTab.home) }
            .tag(AppTab.home)

            NavigationStack(path: $router.mapPath) {
                MapRootView(
                    store: model.mapStore,
                    searchStore: model.mapSearchStore,
                    routeStore: model.routeStore,
                    surface: model.mapSurface
                )
                .navigationDestination(for: AppRoute.self) { route in
                    AppDestinationView(route: route, guidanceStore: model.guidanceStore)
                }
            }
            .environment(\.appRouteRequestHandler, handler(from: .map))
            .tabItem { tabLabel(AppTab.map) }
            .tag(AppTab.map)

            NavigationStack(path: $router.guidePath) {
                GuidanceTopView(store: model.guidanceStore, routeStore: model.routeStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        AppDestinationView(route: route, guidanceStore: model.guidanceStore)
                    }
            }
            .environment(\.appRouteRequestHandler, handler(from: .guide))
            .tabItem { tabLabel(AppTab.guide) }
            .tag(AppTab.guide)

            NavigationStack(path: $router.searchPath) {
                SearchRootView(store: model.searchStore)
                    .navigationDestination(for: AppRoute.self) { route in
                        AppDestinationView(route: route, guidanceStore: model.guidanceStore)
                    }
            }
            .environment(\.appRouteRequestHandler, handler(from: .search))
            .tabItem { tabLabel(AppTab.search) }
            .tag(AppTab.search)
        }
        .tint(.accentColor)
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
