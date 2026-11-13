import Foundation

/// 地点詳細の取得境界。`SpotDetailPresentation` を生成できる唯一の場所。
struct MapContentClient: Sendable {
    /// 地点詳細。イベント ID を渡すと、同じ版から作ったイベント欄（`SpotDetailPresentation.event`）も入れる。
    /// 地点とイベントを1回の読み込みで作るのは、両者を同じ版から読むため（M1-7）。
    var detail: @Sendable (CanonicalSpotID, _ eventID: String?) async throws -> SpotDetailFetchResult
    var failureMessage: NexusStateMessage
}

extension MapContentClient {
    func spotDetail(_ canonicalSpotID: CanonicalSpotID, eventID: String? = nil) async throws -> SpotDetailFetchResult {
        try await detail(canonicalSpotID, eventID)
    }

    /// イベント欄を作らない取得境界（プレビュー・試験用）。イベント ID は無視する。
    init(
        spotDetail: @escaping @Sendable (CanonicalSpotID) async throws -> SpotDetailFetchResult,
        failureMessage: NexusStateMessage
    ) {
        self.init(detail: { canonicalSpotID, _ in try await spotDetail(canonicalSpotID) }, failureMessage: failureMessage)
    }
}

extension MapContentClient {
    static let unconfigured = MapContentClient(
        detail: { _, _ in
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
