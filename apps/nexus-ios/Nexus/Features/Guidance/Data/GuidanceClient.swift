import Foundation

/// 案内の取得境界。既存 `HomeClient` と同じクロージャ構造体スタイル。
/// API の URL・HTTP 仕様・キャッシュ形式・更新頻度はここでは決めない。
struct GuidanceClient: Sendable {
    var fetchTop: @Sendable () async throws -> GuidanceTopFetchResult
    var fetchArticle: @Sendable (GuidanceArticleID) async throws -> GuidanceArticleFetchResult
    var failureMessage: NexusStateMessage
}

extension GuidanceClient {
    static let unconfigured = GuidanceClient(
        fetchTop: {
            throw GuidanceClientError.notConfigured
        },
        fetchArticle: { _ in
            throw GuidanceClientError.notConfigured
        },
        failureMessage: NexusStateMessage(
            title: "案内を読み込めませんでした",
            detail: "案内原稿の接続後に再試行してください。",
            systemImageName: "wifi.slash"
        )
    )
}

private enum GuidanceClientError: Error {
    case notConfigured
}
