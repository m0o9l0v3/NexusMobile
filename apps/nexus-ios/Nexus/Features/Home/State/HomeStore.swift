import Combine
import Foundation

@MainActor
final class HomeStore: ObservableObject {
    @Published private(set) var state: HomeViewState

    private let client: HomeClient
    private var isRefreshing = false

    init(client: HomeClient, initialState: HomeViewState = .idle) {
        self.client = client
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    /// 境界（再表示・前面復帰・bundle の確認後）で読み直す（E2-5 改訂1 §3、#48）。
    ///
    /// Home は時刻で中身が変わる（開始した枠が外れる）うえ、確認で新しい版や中止が届くことがあるため、
    /// 最初の1回だけでは足りない。表示中の内容は読み込み中の表示に戻さず、取得できたら差し替える。
    /// 取得に失敗したときは表示中の内容を残す（取得元は保存版を返すので、失敗は保存版もない場合に限られる）。
    func refresh() async {
        switch state {
        case .idle, .failed:
            await load()
        case .loading:
            return
        case .loaded, .empty, .saved:
            guard !isRefreshing else { return }
            isRefreshing = true
            defer { isRefreshing = false }
            do {
                let result = try await client.fetch()
                guard !Task.isCancelled else { return }
                apply(result)
            } catch {
                // 表示中の内容を残す。
            }
        }
    }

    private func load() async {
        state = .loading

        do {
            let result = try await client.fetch()
            guard !Task.isCancelled else {
                state = .idle
                return
            }
            apply(result)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(client.failureMessage)
        }
    }

    private func apply(_ result: HomeFetchResult) {
        switch result {
        case .fresh(let snapshot):
            state = .loaded(snapshot)
        case .empty(let message, let saved):
            state = .empty(message, saved: saved)
        case .saved(let snapshot, let metadata):
            state = .saved(snapshot, metadata)
        }
    }
}
