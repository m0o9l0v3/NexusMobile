import SwiftUI

struct NexusAppShell: View {
    @State private var selectedTab: AppTab = .home

    private let homeClient: HomeClient
    private let onRouteRequest: (AppRouteRequest) -> Void

    init(
        homeClient: HomeClient,
        onRouteRequest: @escaping (AppRouteRequest) -> Void = { _ in }
    ) {
        self.homeClient = homeClient
        self.onRouteRequest = onRouteRequest
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(client: homeClient, onRouteRequest: onRouteRequest)
            }
            .tabItem {
                tabLabel(AppTab.home)
            }
            .tag(AppTab.home)

            emptyTab(.map)
            emptyTab(.guide)
            emptyTab(.search)
        }
        .tint(.accentColor)
    }

    private func emptyTab(_ tab: AppTab) -> some View {
        NavigationStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .tabItem {
            tabLabel(tab)
        }
        .tag(tab)
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
