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
    /// 読み込みの通し番号。後から始めた読み込みの結果を、先に始めた読み込みの結果で上書きしない
    /// （Map の版切替で読み直している間に、切替前の検索が遅れて終わる場合など、M1-7）。
    private var loadID = 0
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
        await reload()
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
                    await reload()
                }
                return
            }
        }

        if nextQuery.isBlank {
            phase = .initial
            committedQuery = .empty
            draftText = ""
            await reload()
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
            await reload()
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
            await reload()
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

    /// 表示中の bundle の版が切り替わったときに、同じ条件で読み直す（M1-7）。
    /// まだ一度も読んでいなければ何もしない（初回表示で読まれる）。
    func reloadIfLoaded() async {
        guard state != .idle else { return }
        await reload()
    }

    func retry() async {
        if case .failed = state {
            await reload(recheck: true)
        } else {
            await reload()
        }
    }

    /// 更新確認の通知では表示と編集中の条件を保ち、取得結果だけを差し替える。
    func refreshAfterBundleUpdate() async {
        guard state != .idle, state != .loading else { return }
        await reload(quietly: true)
    }

    /// 条件を解除して条件なしの一覧へ戻す（#27 S02）。履歴は消さない。
    func clearConditions() async {
        committedQuery = .empty
        draftText = ""
        unresolvedCategoryID = nil
        phase = .initial
        await reload()
    }

    // MARK: - 実行

    private func commit(_ query: SearchQuery, recordHistory: Bool) async {
        committedQuery = query
        await reload(recordHistory: recordHistory)
    }

    private func reload(recordHistory: Bool = false, recheck: Bool = false, quietly: Bool = false) async {
        loadID += 1
        let requestID = loadID
        let query = committedQuery
        if !quietly { state = .loading }
        if recheck {
            await client.recheck()
            guard requestID == loadID else { return }
        }

        do {
            let next = try await fetch(query)
            guard requestID == loadID else { return }
            if recordHistory { history.record(query) }
            if state != next { state = next }
        } catch {
            guard requestID == loadID else { return }
            if quietly {
                guard case .failed = state, !(error is CancellationError) else { return }
            }
            if error is CancellationError {
                state = .idle
            } else if error as? PublishedBundleSourceError == .updateRequired {
                state = .failed(client.updateRequiredMessage)
            } else {
                state = .failed(client.failureMessage)
            }
        }
    }

    private func fetch(_ query: SearchQuery) async throws -> SearchViewState {
        if !query.isBlank {
            switch try await client.search(query) {
            case .fresh(let snapshot): return .results(snapshot)
            case .empty(let message, let saved): return .empty(message, saved: saved)
            case .saved(let snapshot, let metadata): return .saved(snapshot, metadata)
            }
        }
        switch try await client.initialContent() {
        case .fresh(let snapshot):
            return .initial(snapshot)
        case .empty(let message, let saved):
            return .empty(message, saved: saved)
        case .saved(let snapshot, let metadata):
            // 初期一覧の保存版は結果スナップショットへ写して同じ表示経路に載せる。
            return .saved(
                SearchResultsSnapshot(
                    query: .empty,
                    spots: snapshot.spots,
                    totalCount: snapshot.totalCount
                ),
                metadata
            )
        }
    }
}
