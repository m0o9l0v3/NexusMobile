import SwiftUI

/// 末端の部品（関連地点カード、検索結果行、地点詳細カード）が遷移要求を送るための経路。
/// クロージャを何段も引き回さずに済み、部品はストアを直接読まない。
struct AppRouteRequestHandlerKey: EnvironmentKey {
    static let defaultValue: (AppRouteRequest) -> Void = { request in
        #if DEBUG
        // 配線漏れを無言のデッドエンドにしない。
        print("[Nexus] 未処理の AppRouteRequest: \(request)")
        #endif
    }
}

extension EnvironmentValues {
    var appRouteRequestHandler: (AppRouteRequest) -> Void {
        get { self[AppRouteRequestHandlerKey.self] }
        set { self[AppRouteRequestHandlerKey.self] = newValue }
    }
}
