#if DEBUG
import SwiftUI

/// 保存済みの bundle を MapKit の描画面に描く、DEBUG 専用の描画面（#26）。
///
/// M1 の統合受入（M1 決定記録 §5.1）の予行として、公開された実データの建物・ラベル・ピンを
/// 手元で確かめるためのもの。`source` は Map が固定した版（`PinnedBundleSource`、M1-7）で、
/// `context.contentRevision` が変わったとき（版の切替点）だけ読み直す。
/// 読込中・失敗・保存版の状態の表示は #31・#85 で #84 の承認版に沿って作る。
struct BundleMapSurfaceView: View {
    let source: PublishedBundleSource
    let context: MapSurfaceContext

    @State private var content: CampusMapContent?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let content {
                MapKitMapSurfaceView(
                    content: content,
                    context: context,
                    provisionalNotice: BundleMapSurfaceView.notice
                )
            } else {
                // 保存済みの版がない・読めないときは、本番の既定と同じ未提供の表示にする。
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
            content = snapshot.map { CampusMapContent(bundle: $0.bundle) }
            hasLoaded = true
        }
    }

    static let notice = "DEBUG：保存済みの bundle を表示中（見た目は #84 承認前の仮）"
}

extension MapSurfaceProvider {
    /// 保存済みの bundle を描く DEBUG 専用の描画面。
    static func debugBundle(source: PublishedBundleSource) -> MapSurfaceProvider {
        MapSurfaceProvider(identifier: "debug-bundle-mapkit") { context in
            AnyView(BundleMapSurfaceView(source: source, context: context))
        }
    }
}
#endif
