import Foundation

/// ナビゲーションだけを持つ状態。コンテンツは一切持たない。
///
/// 選択タブと3本のスタックはすべて `TabView` の**上**（`NexusAppShell` の `@State`）に置く。
/// これにより、タブ切替は `selectedTab` の値を1つ書き換えるだけになり、
/// 検索条件・各タブのスタック・選択地点を構造的に破棄できない。
///
/// `AppShellModel` がタブ操作を、`AppRouteCoordinator` が遷移要求を受け取る。
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab
    var homePath: [AppRoute] = []
    var mapPath: [AppRoute] = []
    var guidePath: [AppRoute] = []

    init(selectedTab: AppTab = .home, guidePath: [AppRoute] = []) {
        self.selectedTab = selectedTab
        self.guidePath = guidePath
    }

    func path(for tab: AppTab) -> [AppRoute] {
        switch tab {
        case .home:
            return homePath
        case .map:
            return mapPath
        case .guide:
            return guidePath
        }
    }

    func push(_ route: AppRoute, on tab: AppTab) {
        switch tab {
        case .home:
            homePath.append(route)
        case .map:
            mapPath.append(route)
        case .guide:
            guidePath.append(route)
        }
    }

    func popToRoot(of tab: AppTab) {
        switch tab {
        case .home:
            homePath.removeAll()
        case .map:
            mapPath.removeAll()
        case .guide:
            guidePath.removeAll()
        }
    }

    /// タブを選択する。**選択タブ以外は何も変更しない**のが本メソッドの契約。
    func activate(_ tab: AppTab) {
        selectedTab = tab
    }
}
