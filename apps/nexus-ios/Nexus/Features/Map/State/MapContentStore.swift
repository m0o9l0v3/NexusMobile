import Foundation

/// Map の地図の内容を読み、読込中・掲載なし・失敗を区別する（#31）。
///
/// 読むのは Map が固定した版（`PinnedBundleSource`、M1-7）で、地点詳細・Map の検索と同じ版を見る。
/// 再試行では取得元にすぐ1回確認させ（`recheck`）、`advance` で版の切替点を通してから読み直す。
/// 切替点を通すのは `MapStore` で、地図・地点詳細・検索をまとめて同じ版へ移す。
@MainActor
@Observable
final class MapContentStore {
    private(set) var state: MapContentState = .loading

    @ObservationIgnored private let source: PublishedBundleSource
    /// 読み込みの通し番号。古い読み込みの結果で新しい表示を上書きしない。
    @ObservationIgnored private var loadID = 0
    @ObservationIgnored private var isRetrying = false

    init(source: PublishedBundleSource) {
        self.source = source
    }

    /// いまの版を読む。地図がすでにあれば、読み直す間も地図を出したままにする（読込中を挟まない）。
    func load() async {
        loadID += 1
        let id = loadID
        if !state.isLoaded {
            state = .loading
        }
        let result: Result<PublishedBundleSnapshot?, Error>
        do {
            result = .success(try await source.current())
        } catch is CancellationError {
            return
        } catch {
            result = .failure(error)
        }
        var absence = PublishedBundleAbsence.unknown
        if case .success(nil) = result {
            absence = await source.absence()
        }
        guard id == loadID else { return }
        state = MapContentState.resolve(result, absence: absence)
    }

    /// 失敗の表示の「再試行」。読込中を出し、確認 → 版の切替点 → 読み直しの順に進める。
    /// - Parameter advance: 版の切替点（`MapStore.mapContentRetried()`）。
    func retry(advance: @MainActor () async -> Void) async {
        guard state.allowsRetry, !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        loadID += 1
        state = .loading
        await source.recheck()
        await advance()
        await load()
    }
}
