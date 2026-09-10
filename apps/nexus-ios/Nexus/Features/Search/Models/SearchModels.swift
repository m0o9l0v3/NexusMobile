import Foundation

/// Figma `2622:818` のカテゴリチップ。「すべて」は `nil` で表す。
enum SearchCategoryID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case classroom
    case facility
    case service

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classroom:
            return "教室"
        case .facility:
            return "施設"
        case .service:
            return "サービス"
        }
    }
}

/// 検索条件。Home と探すで同じ型を使い、同じ語・条件なら同じ結果になるようにする。
struct SearchQuery: Equatable, Hashable, Sendable {
    let text: String
    let categoryID: SearchCategoryID?

    static let empty = SearchQuery(text: "", categoryID: nil)

    init(text: String, categoryID: SearchCategoryID? = nil) {
        self.text = text
        self.categoryID = categoryID
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool {
        trimmedText.isEmpty && categoryID == nil
    }
}

/// 検索結果。
struct SearchResultsSnapshot: Equatable, Sendable {
    let query: SearchQuery
    let spots: [SpotSummary]
    let totalCount: Int

    init(query: SearchQuery, spots: [SpotSummary], totalCount: Int? = nil) {
        self.query = query
        self.spots = spots
        self.totalCount = totalCount ?? spots.count
    }
}

/// 探す初期表示（Figma `2622:818` の「すべての地点」一覧）。
struct SearchInitialSnapshot: Equatable, Sendable {
    let headingText: String
    let spots: [SpotSummary]
    let totalCount: Int
    let categories: [SearchCategoryID]

    init(
        headingText: String,
        spots: [SpotSummary],
        totalCount: Int? = nil,
        categories: [SearchCategoryID] = SearchCategoryID.allCases
    ) {
        self.headingText = headingText
        self.spots = spots
        self.totalCount = totalCount ?? spots.count
        self.categories = categories
    }
}

enum SearchFetchResult: Equatable, Sendable {
    case fresh(SearchResultsSnapshot)
    case empty(NexusStateMessage)
    case saved(SearchResultsSnapshot, NexusSavedMetadata)
}

enum SearchInitialFetchResult: Equatable, Sendable {
    case fresh(SearchInitialSnapshot)
    case empty(NexusStateMessage)
    case saved(SearchInitialSnapshot, NexusSavedMetadata)
}

/// 探す画面内の局面。画面遷移ではなく同一画面の状態（Figma もその構造）。
enum SearchPhase: Equatable, Sendable {
    /// `2622:818` Initial
    case initial
    /// `2672:2046` Search Active（キーボード表示）
    case focused
    /// `2637:1512` Results
    case results
}

/// 検索状態の表示内容。
///
/// **0件（`.empty`）/ 取得失敗（`.failed`）/ 保存版（`.saved`）は最後まで別物として扱う。**
/// v04「取得失敗を0件にしない」。
enum SearchViewState: Equatable, Sendable {
    case idle
    case loading
    case initial(SearchInitialSnapshot)
    case results(SearchResultsSnapshot)
    case empty(NexusStateMessage)
    case failed(NexusStateMessage)
    case saved(SearchResultsSnapshot, NexusSavedMetadata)
}

/// 検索UIが載っている面。探すタブと Map の検索状態で別インスタンスを持つための識別子。
enum SearchSurface: Hashable, Sendable {
    case search
    case map
}
