import SwiftUI

/// 地図の描画面でピン・建物を選んだことを Map タブへ伝える経路（M1 決定記録 §5.1-3）。
///
/// 描画面は `MapSurfaceProvider` が作り、`MapStore` を直接持たない。`MapSurfaceContext` は
/// 等価比較する値なのでクロージャを入れず、環境で渡す。
struct MapSpotSelectionHandlerKey: EnvironmentKey {
    static let defaultValue: @MainActor (CanonicalSpotID) -> Void = { spotID in
        #if DEBUG
        // 配線漏れを無言のデッドエンドにしない。
        print("[Nexus] 未処理の地図上の地点選択: \(spotID.rawValue)")
        #endif
    }
}

extension EnvironmentValues {
    var mapSpotSelectionHandler: @MainActor (CanonicalSpotID) -> Void {
        get { self[MapSpotSelectionHandlerKey.self] }
        set { self[MapSpotSelectionHandlerKey.self] = newValue }
    }
}
