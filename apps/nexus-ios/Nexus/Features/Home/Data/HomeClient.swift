import Foundation

struct HomeClient: Sendable {
    var fetch: @Sendable () async throws -> HomeFetchResult
    var failureMessage: HomeStateMessage
    /// 案内ショートカット（Home v1.0 下書き B）。同梱の案内原稿から作り、bundle の取得とは独立に読む。
    var guidanceShortcuts: @Sendable () async -> [HomeGuidanceShortcut] = { [] }
}

extension HomeClient {
    static let unconfigured = HomeClient(
        fetch: {
            throw HomeClientError.notConfigured
        },
        failureMessage: HomeStateMessage(
            title: "ホームを読み込めませんでした",
            detail: "データ取得先の接続後に再試行してください。",
            systemImageName: "wifi.slash"
        )
    )
}

private enum HomeClientError: Error {
    case notConfigured
}

extension HomeClient {
    /// 同梱の案内原稿（`GuidanceArticles.json`）から、記事があるショートカットだけを返す。
    /// 原稿を読めないときは何も出さない（案内タブ側が失敗を表示する）。
    static func bundledGuidanceShortcuts(resourceURL: URL?) -> @Sendable () async -> [HomeGuidanceShortcut] {
        {
            guard let resourceURL,
                  let data = try? Data(contentsOf: resourceURL),
                  let catalog = try? BundledGuidanceCatalog.decode(data)
            else {
                return []
            }
            return catalog.homeShortcuts
        }
    }
}
