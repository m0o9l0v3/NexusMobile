import Combine
import Foundation

/// 「すべてのイベント」の状態。カテゴリの絞り込みは画面の中の状態として持つ（下書き §5 C）。
@MainActor
final class EventListStore: ObservableObject {
    @Published private(set) var state: EventListViewState
    /// 選んだカテゴリ。nil は「すべて」。
    @Published var selectedCategoryID: String?

    private let client: EventListClient
    private var isRefreshing = false

    init(client: EventListClient, initialState: EventListViewState = .idle) {
        self.client = client
        state = initialState
    }

    func retry() async {
        await load()
    }

    /// Home と同じ境界（再表示・前面復帰・bundle の確認後）で読み直す（#48）。
    /// 表示中の内容は読み込み中に戻さず、失敗したときは残す。
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

    /// 表示中の一覧（保存版を含む）。
    var snapshot: EventListSnapshot? {
        switch state {
        case .loaded(let snapshot), .saved(let snapshot, _):
            return snapshot
        case .idle, .loading, .empty, .failed:
            return nil
        }
    }

    /// 選んだカテゴリで絞った日ごとの枠。
    var visibleDays: [EventListDay] {
        snapshot?.days(in: selectedCategoryID) ?? []
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

    private func apply(_ result: EventListFetchResult) {
        switch result {
        case .fresh(let snapshot):
            state = .loaded(snapshot)
        case .empty(let message, let saved):
            state = .empty(message, saved: saved)
        case .saved(let snapshot, let metadata):
            state = .saved(snapshot, metadata)
        }
        // 新しい版で選んでいたカテゴリが消えたら「すべて」に戻す。
        if let selected = selectedCategoryID,
           !(snapshot?.categories.contains { $0.id == selected } ?? false) {
            selectedCategoryID = nil
        }
    }
}
