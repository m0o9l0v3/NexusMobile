#if DEBUG
import Foundation

/// 地図の状態（#31）の画面確認用。DEBUG の起動引数 `-NexusMapState <case>` と `-NexusPreviewScreen map`。
///
/// 構内の測量データが届くまで本番の取得元は地図を返さないため、本番と同じ bundle の描画面に
/// 決めた結果を返す取得元を渡す。地図がある状態は `-NexusMapKitCheck`（検証用の14棟）で見る。
enum MapContentStateFixture: String, CaseIterable {
    /// 読み込みが終わらない。
    case loading
    /// まだ公開されていない（404）。掲載なし。
    case notPublished
    /// 通信できない。再試行を押しても失敗のまま。
    case failed
    /// 未知のメジャー版。アプリの更新が必要。
    case updateRequired

    var source: PublishedBundleSource {
        switch self {
        case .loading:
            return PublishedBundleSource(current: {
                try await Task.sleep(for: .seconds(3600))
                return nil
            })
        case .notPublished:
            return .fixed(nil, absence: .notPublished)
        case .failed:
            return PublishedBundleSource(
                current: {
                    // 再試行で読込中が見えるよう、少し待ってから失敗を返す。
                    try await Task.sleep(for: .milliseconds(600))
                    return nil
                },
                absence: { .checkFailed }
            )
        case .updateRequired:
            return .fixed(nil, absence: .updateRequired)
        }
    }
}
#endif
