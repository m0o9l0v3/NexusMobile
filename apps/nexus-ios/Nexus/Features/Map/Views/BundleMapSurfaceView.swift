import SwiftUI

/// 公開された bundle を MapKit で描く、Map の本番の描画面（#26）。
///
/// `source` は Map が固定した版（`PinnedBundleSource`、M1-7）で、`context.contentRevision` が
/// 変わったとき（版の切替点）だけ読み直す。描くのは14棟の建物の形・ラベルと、公開された地点のピン。
///
/// 保存版がない・読めない・描けるものがないときは、未提供の表示（`UnavailableMapSurfaceView`）にする。
/// 読込中・掲載なし（404）・失敗・保存版の区別の表示は #31 で #84 の承認版に沿って作る。
struct BundleMapSurfaceView: View {
    let source: PublishedBundleSource
    let context: MapSurfaceContext

    @State private var content: CampusMapContent?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let content {
                MapKitMapSurfaceView(content: content, context: context)
            } else {
                UnavailableMapSurfaceView(context: context)
                    .overlay(alignment: .bottom) {
                        if !hasLoaded {
                            ProgressView()
                                .padding(.bottom, 120)
                        }
                    }
            }
        }
        .task(id: context.contentRevision) {
            let snapshot = try? await source.current()
            content = Self.drawableContent(from: snapshot)
            hasLoaded = true
        }
    }

    /// 描けるものが1つもなければ nil。空の地図（世界地図）を構内地図のように見せない。
    static func drawableContent(from snapshot: PublishedBundleSnapshot?) -> CampusMapContent? {
        guard let snapshot else { return nil }
        let content = CampusMapContent(bundle: snapshot.bundle)
        guard !content.buildings.isEmpty || !content.pins.isEmpty else { return nil }
        return content
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
