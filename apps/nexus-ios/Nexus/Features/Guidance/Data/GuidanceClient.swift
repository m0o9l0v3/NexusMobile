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

extension GuidanceClient {
    /// アプリに同梱した案内原稿を読む（E6-6 案A）。通信の有無で振る舞いを変えない（E6-6 §3）。
    ///
    /// 原稿ファイルが無い・壊れている・公開条件を欠く記事があるときは、記事を1件も出さず失敗にする。
    /// 同梱ファイルは試験（`BundledGuidanceCatalogTests`）で検証するので、ここに来るのは配布物の不備だけ。
    static func bundled(resourceURL: URL?) -> GuidanceClient {
        let load: @Sendable () throws -> BundledGuidanceCatalog = {
            guard let resourceURL else {
                throw BundledGuidanceCatalogError.resourceMissing
            }
            return try BundledGuidanceCatalog.decode(Data(contentsOf: resourceURL))
        }

        return GuidanceClient(
            fetchTop: {
                try load().topFetchResult
            },
            fetchArticle: { id in
                try load().articleFetchResult(for: id)
            },
            failureMessage: NexusStateMessage(
                title: "案内を読み込めませんでした",
                detail: "アプリに同梱した案内を読めませんでした。アプリを最新版に更新してください。",
                systemImageName: "exclamationmark.triangle"
            )
        )
    }

    /// `Bundle.main` の `GuidanceArticles.json` を読む。
    static var bundledInApp: GuidanceClient {
        .bundled(
            resourceURL: Bundle.main.url(
                forResource: BundledGuidanceCatalog.resourceName,
                withExtension: BundledGuidanceCatalog.resourceExtension
            )
        )
    }
}
