#if DEBUG
import SwiftUI

/// Preview／シミュレーター比較専用の検討用データ。
///
/// **正式な地点データではない。** Figma 上の仮表示（2A教室・食堂・格納庫A）をそのまま持つ。
/// 本ファイルは `#if DEBUG` で囲まれており、Release ビルドには含まれない。
/// fixture を返す便利メソッドは本ファイルにだけ置き、本番既定（`.unconfigured`）は
/// クライアント宣言の隣に置く。
enum SearchPreviewFixtures {
    /// プロンプトが代表 canonical ID として指定した値。
    static let classroom2A = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
        displayName: "2A教室",
        kind: .classroom,
        buildingName: "教室棟",
        floorName: "2F"
    )

    static let diningHall = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "dh"),
        displayName: "食堂",
        kind: .service,
        buildingName: "構内"
    )

    static let hangarA = SpotSummary(
        canonicalSpotID: CanonicalSpotID(rawValue: "hgr_a"),
        displayName: "格納庫A",
        kind: .facility,
        buildingName: "構内"
    )

    static let allSpots: [SpotSummary] = [classroom2A, diningHall, hangarA]

    static let initialSnapshot = SearchInitialSnapshot(
        headingText: "すべての地点",
        spots: allSpots
    )

    static let emptyMessage = NexusStateMessage(
        title: "該当する地点はありません",
        detail: "別の語で検索するか、条件を解除してください。",
        systemImageName: "magnifyingglass"
    )

    static let savedMetadata = NexusSavedMetadata(
        title: "保存版を表示しています",
        detail: "最新情報は確認できていません。"
    )

    /// 検討用の簡易照合。表示名は大小文字を無視して照合するが、
    /// canonical ID には一切触れない（正規化しない）。
    static func results(for query: SearchQuery) -> SearchResultsSnapshot {
        let text = query.trimmedText.lowercased()
        let matched = allSpots.filter { spot in
            let matchesText = text.isEmpty || spot.displayName.lowercased().contains(text)
            let matchesCategory: Bool
            switch query.categoryID {
            case .none:
                matchesCategory = true
            case .some(.classroom):
                matchesCategory = spot.kind == .classroom
            case .some(.facility):
                matchesCategory = spot.kind == .facility
            case .some(.service):
                matchesCategory = spot.kind == .service
            }
            return matchesText && matchesCategory
        }
        return SearchResultsSnapshot(query: query, spots: matched)
    }
}

extension SearchClient {
    /// Preview／シミュレーター比較用。Release には存在しない。
    static func preview(
        initial: SearchInitialFetchResult = .fresh(SearchPreviewFixtures.initialSnapshot),
        results: (@Sendable (SearchQuery) -> SearchFetchResult)? = nil
    ) -> SearchClient {
        SearchClient(
            initialContent: { initial },
            search: { query in
                if let results {
                    return results(query)
                }
                let snapshot = SearchPreviewFixtures.results(for: query)
                return snapshot.spots.isEmpty
                    ? .empty(SearchPreviewFixtures.emptyMessage)
                    : .fresh(snapshot)
            },
            failureMessage: SearchClient.unconfigured.failureMessage
        )
    }

    static func previewFailing() -> SearchClient {
        SearchClient(
            initialContent: { throw SearchPreviewError.simulated },
            search: { _ in throw SearchPreviewError.simulated },
            failureMessage: SearchClient.unconfigured.failureMessage
        )
    }
}

enum SearchPreviewError: Error {
    case simulated
}

@MainActor
private func previewStore(
    client: SearchClient = .preview(),
    phase: SearchPhase = .initial,
    query: SearchQuery = .empty,
    state: SearchViewState = .idle
) -> SearchStore {
    SearchStore(
        client: client,
        history: SearchHistoryStore(entries: [
            SearchQuery(text: "第1体育館"),
            SearchQuery(text: "航空工学科"),
            SearchQuery(text: "ドローン体験"),
        ]),
        surface: .search,
        initialState: state,
        initialQuery: query,
        initialPhase: phase
    )
}

#Preview("探す・初期 393×852") {
    NavigationStack {
        SearchRootView(store: previewStore(state: .initial(SearchPreviewFixtures.initialSnapshot)))
    }
}

#Preview("探す・入力中") {
    NavigationStack {
        SearchRootView(
            store: previewStore(
                phase: .focused,
                state: .initial(SearchPreviewFixtures.initialSnapshot)
            )
        )
    }
}

#Preview("探す・結果 mb_f2_cr_2a") {
    NavigationStack {
        SearchRootView(
            store: previewStore(
                phase: .results,
                query: SearchQuery(text: "2A", categoryID: .classroom),
                state: .results(
                    SearchResultsSnapshot(
                        query: SearchQuery(text: "2A", categoryID: .classroom),
                        spots: [SearchPreviewFixtures.classroom2A]
                    )
                )
            )
        )
    }
}

#Preview("探す・0件") {
    NavigationStack {
        SearchRootView(
            store: previewStore(
                phase: .results,
                query: SearchQuery(text: "存在しない語"),
                state: .empty(SearchPreviewFixtures.emptyMessage)
            )
        )
    }
}

#Preview("探す・読込中") {
    NavigationStack {
        SearchRootView(store: previewStore(state: .loading))
    }
}

#Preview("探す・通信失敗") {
    NavigationStack {
        SearchRootView(
            store: previewStore(
                client: .previewFailing(),
                state: .failed(SearchClient.unconfigured.failureMessage)
            )
        )
    }
}

#Preview("探す・保存版") {
    NavigationStack {
        SearchRootView(
            store: previewStore(
                state: .saved(
                    SearchResultsSnapshot(query: .empty, spots: SearchPreviewFixtures.allSpots),
                    SearchPreviewFixtures.savedMetadata
                )
            )
        )
    }
}

#Preview("探す・ダーク") {
    NavigationStack {
        SearchRootView(store: previewStore(state: .initial(SearchPreviewFixtures.initialSnapshot)))
    }
    .preferredColorScheme(.dark)
}

#Preview("探す・AXXXL") {
    NavigationStack {
        SearchRootView(store: previewStore(state: .initial(SearchPreviewFixtures.initialSnapshot)))
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
