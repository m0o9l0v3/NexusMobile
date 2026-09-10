import Foundation

/// 案内トップと各記事の状態。
///
/// 記事の状態は**記事IDをキーにした辞書1つ**で持つ。画面ごとにストアを分けないので、
/// 記事A → 戻る → 記事B → 戻る → 記事A で再取得が起きない。
@MainActor
@Observable
final class GuidanceStore {
    private(set) var topState: GuidanceTopViewState
    private(set) var articleStates: [GuidanceArticleID: GuidanceArticleViewState]

    private let client: GuidanceClient

    init(
        client: GuidanceClient,
        initialTopState: GuidanceTopViewState = .idle,
        initialArticleStates: [GuidanceArticleID: GuidanceArticleViewState] = [:]
    ) {
        self.client = client
        self.topState = initialTopState
        self.articleStates = initialArticleStates
    }

    // MARK: - 案内トップ

    func loadTopIfNeeded() async {
        guard topState == .idle else { return }
        await loadTop()
    }

    func retryTop() async {
        await loadTop()
    }

    private func loadTop() async {
        topState = .loading
        do {
            switch try await client.fetchTop() {
            case .fresh(let snapshot):
                topState = .loaded(snapshot)
            case .empty(let message):
                topState = .empty(message)
            case .saved(let snapshot, let metadata):
                topState = .saved(snapshot, metadata)
            }
        } catch is CancellationError {
            topState = .idle
        } catch {
            topState = .failed(client.failureMessage)
        }
    }

    // MARK: - 案内詳細

    func articleState(for id: GuidanceArticleID) -> GuidanceArticleViewState {
        articleStates[id] ?? .idle
    }

    func loadArticleIfNeeded(_ id: GuidanceArticleID) async {
        guard articleState(for: id) == .idle else { return }
        await loadArticle(id)
    }

    func retryArticle(_ id: GuidanceArticleID) async {
        await loadArticle(id)
    }

    private func loadArticle(_ id: GuidanceArticleID) async {
        articleStates[id] = .loading
        do {
            switch try await client.fetchArticle(id) {
            case .fresh(let article):
                articleStates[id] = .loaded(article)
            case .saved(let article, let metadata):
                articleStates[id] = .saved(article, metadata)
            case .notProvided(let requestedID):
                // 要求された ID をそのまま返す。別記事へフォールバックしない。
                articleStates[id] = .notProvided(requestedID)
            }
        } catch is CancellationError {
            articleStates[id] = .idle
        } catch {
            articleStates[id] = .failed(client.failureMessage)
        }
    }
}
