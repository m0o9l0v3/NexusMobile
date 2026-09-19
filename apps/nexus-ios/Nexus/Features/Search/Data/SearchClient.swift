import Foundation

/// 検索の取得境界。既存 `HomeClient` と同じクロージャ構造体スタイル。
///
/// 名称照合のかな／英字／略称の正規化はクライアント側の責務。
/// **canonical ID の照合は大小文字を区別する完全一致**で、正規化してはならない
/// （`docs/decisions/E1-3`）。
struct SearchClient: Sendable {
    var initialContent: @Sendable () async throws -> SearchInitialFetchResult
    var search: @Sendable (SearchQuery) async throws -> SearchFetchResult
    var failureMessage: NexusStateMessage
}

extension SearchClient {
    static let unconfigured = SearchClient(
        initialContent: {
            throw SearchClientError.notConfigured
        },
        search: { _ in
            throw SearchClientError.notConfigured
        },
        failureMessage: NexusStateMessage(
            title: "検索データを読み込めませんでした",
            detail: "データ取得先の接続後に再試行してください。",
            systemImageName: "wifi.slash"
        )
    )
}

private enum SearchClientError: Error {
    case notConfigured
}
