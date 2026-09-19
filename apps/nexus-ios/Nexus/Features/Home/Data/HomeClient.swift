import Foundation

struct HomeClient: Sendable {
    var fetch: @Sendable () async throws -> HomeFetchResult
    var failureMessage: HomeStateMessage
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
