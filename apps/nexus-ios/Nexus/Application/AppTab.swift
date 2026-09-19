import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case map
    case guide
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .map:
            return "マップ"
        case .guide:
            return "案内"
        case .search:
            return "探す"
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house"
        case .map:
            return "map"
        case .guide:
            return "info.circle"
        case .search:
            return "magnifyingglass"
        }
    }

    var assetImageName: String? {
        switch self {
        case .map:
            return "MapTabIcon"
        case .guide:
            return "GuideTabIcon"
        case .home, .search:
            return nil
        }
    }
}
