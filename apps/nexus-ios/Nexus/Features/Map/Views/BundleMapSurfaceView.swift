import SwiftUI

/// 公開された bundle を MapKit で描く、Map の本番の描画面（#26）。
///
/// `source` は Map が固定した版（`PinnedBundleSource`、M1-7）で、`context.contentRevision` が
/// 変わったとき（版の切替点）だけ読み直す。描くのは14棟の建物の形・ラベルと、公開された地点のピン。
///
/// 地図を描けないときは、読込中・掲載なし・失敗（再試行あり）を分けて出す（#31、`MapContentStore`）。
struct BundleMapSurfaceView: View {
    let source: PublishedBundleSource
    let context: MapSurfaceContext

    @State private var store: MapContentStore
    @Environment(\.mapContentRetryHandler) private var retryHandler

    init(source: PublishedBundleSource, context: MapSurfaceContext) {
        self.source = source
        self.context = context
        _store = State(initialValue: MapContentStore(source: source))
    }

    var body: some View {
        Group {
            if case .loaded(let content) = store.state {
                MapKitMapSurfaceView(content: content, context: context)
            } else if let kind = MapSurfaceStateView.Kind(store.state) {
                MapSurfaceStateView(kind: kind, focusedSpotID: context.focusedSpotID) {
                    Task { await store.retry(advance: retryHandler) }
                }
            }
        }
        .task(id: context.contentRevision) {
            await store.load()
        }
        // 失敗・掲載なしになったことを VoiceOver に伝える（地図の面は読み上げの順が後ろのため）。
        .onChange(of: store.state.message) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message.title).post()
            }
        }
    }
}

extension MapSurfaceProvider {
    /// 公開された bundle を描く描画面。接続先が設定されているときの既定（#26）。
    static func bundle(source: PublishedBundleSource) -> MapSurfaceProvider {
        MapSurfaceProvider(identifier: "bundle-mapkit") { context in
            AnyView(BundleMapSurfaceView(source: source, context: context))
        }
    }
}
