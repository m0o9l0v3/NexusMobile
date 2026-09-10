import Foundation

/// 探す／Map 検索の状態。
///
/// タブ切替で条件が消えないことが要件なので、このストアは `TabView` の上で生成され、
/// タブの View 階層が破棄されても生き残る。
@MainActor
@Observable
final class SearchStore {
    private(set) var state: SearchViewState
    private(set) var phase: SearchPhase
    /// 実際に検索を実行した条件。入力途中の `draftText` とは別物。
    private(set) var committedQuery: SearchQuery
    /// `HomeSearchRequest.categoryID` が既知のカテゴリへ解決できなかった場合の原文。
    ///
    /// 未知カテゴリを黙って「すべて」に落とすと、利用者は絞り込めていると誤認する。
    /// 未知の地点IDを別地点へ置換するのと同じ問題なので、落とした事実を観測可能にする。
    private(set) var unresolvedCategoryID: String?

    /// 入力欄の編集中テキスト。
    var draftText: String

    let surface: SearchSurface

    private let client: SearchClient
    private let history: SearchHistoryStore

    init(
        client: SearchClient,
        history: SearchHistoryStore,
        surface: SearchSurface,
        initialState: SearchViewState = .idle,
        initialQuery: SearchQuery = .empty,
        initialPhase: SearchPhase = .initial
    ) {
        self.client = client
        self.history = history
        self.surface = surface
        self.state = initialState
        self.committedQuery = initialQuery
        self.phase = initialPhase
        self.draftText = initialQuery.text
    }

    var historyEntries: [SearchQuery] {
        history.entries
    }

    var hasActiveConditions: Bool {
        !committedQuery.isBlank
    }

    // MARK: - 初期表示

    func loadInitialIfNeeded() async {
        guard state == .idle else { return }
        await loadInitial()
    }

    private func loadInitial() async {
        state = .loading
        do {
            switch try await client.initialContent() {
            case .fresh(let snapshot):
                state = .initial(snapshot)
            case .empty(let message):
                state = .empty(message)
            case .saved(let snapshot, let metadata):
                // 初期一覧の保存版は結果スナップショットへ写して同じ表示経路に載せる。
                state = .saved(
                    SearchResultsSnapshot(
                        query: .empty,
                        spots: snapshot.spots,
                        totalCount: snapshot.totalCount
                    ),
                    metadata
                )
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(client.failureMessage)
        }
    }

    // MARK: - Home / 他タブからの入場

    /// Home の検索欄・カテゴリからの入場を反映する。
    ///
    /// - `clearsPreviousConditions`: 以前の語・条件を解除して新規検索にする（v04 P11 の動作案）
    /// - `focusesInput`: 入力にフォーカスしてキーボードを出す。検索は実行しない
    /// - `categoryID` 指定あり: 条件を明示した一覧を出す。キーボードは自動表示しない
    func apply(_ request: HomeSearchRequest) async {
        if request.intent.clearsPreviousConditions {
            committedQuery = .empty
            draftText = ""
            unresolvedCategoryID = nil
        }

        var resolvedCategory = committedQuery.categoryID
        if let rawCategoryID = request.categoryID {
            if let known = SearchCategoryID(rawValue: rawCategoryID) {
                resolvedCategory = known
                unresolvedCategoryID = nil
            } else {
                // 未知カテゴリ。すべて扱いに落とすが、落とした事実を保持する。
                resolvedCategory = nil
                unresolvedCategoryID = rawCategoryID
            }
        }

        let resolvedText = request.query ?? (request.intent.clearsPreviousConditions ? "" : committedQuery.text)
        let nextQuery = SearchQuery(text: resolvedText, categoryID: resolvedCategory)

        if request.intent.focusesInput {
            phase = .focused
            draftText = nextQuery.text
            committedQuery = nextQuery
            if nextQuery.isBlank {
                // 入力待ち。まだ検索しない。
                if state == .idle {
                    await loadInitial()
                }
                return
            }
        }

        if nextQuery.isBlank {
            phase = .initial
            committedQuery = .empty
            draftText = ""
            await loadInitial()
            return
        }

        // カテゴリ入場・語つき入場は結果を表示する。キーボードは出さない。
        if !request.intent.focusesInput {
            phase = .results
        }
        draftText = nextQuery.text
        await commit(nextQuery, recordHistory: !nextQuery.trimmedText.isEmpty)
    }

    // MARK: - 画面内の操作

    func beginEditing() {
        guard phase != .focused else { return }
        phase = .focused
    }

    func endEditing() {
        guard phase == .focused else { return }
        phase = hasActiveConditions ? .results : .initial
    }

    func selectCategory(_ categoryID: SearchCategoryID?) async {
        unresolvedCategoryID = nil
        let nextQuery = SearchQuery(text: draftText, categoryID: categoryID)
        if nextQuery.isBlank {
            committedQuery = .empty
            phase = .initial
            await loadInitial()
            return
        }
        phase = .results
        await commit(nextQuery, recordHistory: false)
    }

    func submit() async {
        let nextQuery = SearchQuery(text: draftText, categoryID: committedQuery.categoryID)
        if nextQuery.isBlank {
            committedQuery = .empty
            phase = .initial
            await loadInitial()
            return
        }
        phase = .results
        await commit(nextQuery, recordHistory: true)
    }

    func selectHistoryEntry(_ query: SearchQuery) async {
        unresolvedCategoryID = nil
        draftText = query.text
        phase = .results
        await commit(query, recordHistory: true)
    }

    func retry() async {
        if committedQuery.isBlank {
            await loadInitial()
        } else {
            await commit(committedQuery, recordHistory: false)
        }
    }

    /// 条件を解除して条件なしの一覧へ戻す（#27 S02）。履歴は消さない。
    func clearConditions() async {
        committedQuery = .empty
        draftText = ""
        unresolvedCategoryID = nil
        phase = .initial
        await loadInitial()
    }

    // MARK: - 実行

    private func commit(_ query: SearchQuery, recordHistory: Bool) async {
        committedQuery = query
        state = .loading
        do {
            let result = try await client.search(query)
            if recordHistory {
                history.record(query)
            }
            switch result {
            case .fresh(let snapshot):
                state = .results(snapshot)
            case .empty(let message):
                state = .empty(message)
            case .saved(let snapshot, let metadata):
                state = .saved(snapshot, metadata)
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(client.failureMessage)
        }
    }
}
