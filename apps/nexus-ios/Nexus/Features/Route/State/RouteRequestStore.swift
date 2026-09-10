import Foundation

/// 経路確認要求の状態。
///
/// **不変条件**: `activeDestination` へ書き込むのは `requestRoute(to:from:)` の
/// `.accepted` 分岐だけ。`.unknownSpot` / `.unavailable` は既存の目的地を保持する。
/// 外部に setter を公開しないので、「地点を閲覧しただけで案内先が変わる」ことが
/// 構造的に起こらない（#85 M14 / プロンプト §10）。
@MainActor
@Observable
final class RouteRequestStore {
    private(set) var activeDestination: RouteDestination?
    private(set) var lastOutcome: RouteRequestOutcome?
    private(set) var isRequesting = false

    private let handler: RouteRequestHandling

    init(handler: RouteRequestHandling, initialDestination: RouteDestination? = nil) {
        self.handler = handler
        self.activeDestination = initialDestination
    }

    func requestRoute(to canonicalSpotID: CanonicalSpotID, from tab: AppTab) async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        let outcome = await handler.requestRoute(canonicalSpotID, tab)
        lastOutcome = outcome

        if case .accepted(let destination) = outcome {
            activeDestination = destination
        }
    }

    func dismissNotice() {
        lastOutcome = nil
    }

    /// 進行中の案内を明示的に終了する。閲覧操作からは呼ばない。
    func clearDestination() {
        activeDestination = nil
    }
}
