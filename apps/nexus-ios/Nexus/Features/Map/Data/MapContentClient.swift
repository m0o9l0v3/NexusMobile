import Foundation

/// 地点詳細の取得境界。`SpotDetailPresentation` を生成できる唯一の場所。
struct MapContentClient: Sendable {
    var spotDetail: @Sendable (CanonicalSpotID) async throws -> SpotDetailFetchResult
    var failureMessage: NexusStateMessage
}

extension MapContentClient {
    static let unconfigured = MapContentClient(
        spotDetail: { _ in
            throw MapContentClientError.notConfigured
        },
        failureMessage: NexusStateMessage(
            title: "地点情報を読み込めませんでした",
            detail: "地点データの接続後に再試行してください。",
            systemImageName: "mappin.slash"
        )
    )
}

private enum MapContentClientError: Error {
    case notConfigured
}
