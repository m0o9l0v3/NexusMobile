import Foundation

/// Map が表示する bundle の版を切り替える境界（M1-7）。
///
/// 地点詳細を閉じたとき・Map タブを開き直したときに `MapStore` が呼ぶ。
/// 新しい版へ切り替えたときだけ true を返し、`MapStore` は地図・詳細・検索をまとめて読み直す。
struct MapSnapshotBoundary: Sendable {
    var advance: @Sendable () async -> Bool
}

extension MapSnapshotBoundary {
    /// 版を持たない構成（未接続・Preview）。切り替えない。
    static let none = MapSnapshotBoundary(advance: { false })

    static func pinned(_ source: PinnedBundleSource) -> MapSnapshotBoundary {
        MapSnapshotBoundary(advance: { await source.advance() })
    }
}
