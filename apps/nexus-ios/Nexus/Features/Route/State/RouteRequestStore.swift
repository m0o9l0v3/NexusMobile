import Foundation

/// 経路確認要求の状態。
///
/// 受理した要求だけが案内先を更新する。同一点・失敗・地点の閲覧では案内を保持する（#85 M14）。
@MainActor
@Observable
final class RouteRequestStore {
    private(set) var activeDestination: RouteDestination?
    var activeRoute: ResolvedRoute? { activeDestination?.resolvedRoute }
    private(set) var lastOutcome: RouteRequestOutcome?
    private(set) var isRequesting = false

    private var requestRevision = 0
    private(set) var outcomeRevision = 0
    private let handler: RouteRequestHandling

    init(handler: RouteRequestHandling, initialDestination: RouteDestination? = nil) {
        self.handler = handler
        self.activeDestination = initialDestination
    }

    func requestRoute(to canonicalSpotID: CanonicalSpotID, from tab: AppTab) async {
        await requestRoute(from: nil, to: canonicalSpotID, from: tab)
    }

    func requestRoute(from origin: RouteOrigin?, to canonicalSpotID: CanonicalSpotID, from tab: AppTab) async {
        guard !isRequesting else { return }
        isRequesting = true
        let revision = requestRevision
        let outcome = await handler.resolve(origin: origin, destination: canonicalSpotID, from: tab)
        guard requestRevision == revision else { return }
        isRequesting = false
        outcomeRevision += 1
        lastOutcome = outcome

        if case .accepted(let destination) = outcome {
            activeDestination = destination
        }
    }

    func endGuidance() {
        requestRevision += 1
        isRequesting = false
        activeDestination = nil
        lastOutcome = nil
    }

    func dismissNotice() {
        lastOutcome = nil
    }

    /// 進行中の案内を明示的に終了する。閲覧操作からは呼ばない。
    func clearDestination() {
        activeDestination = nil
    }
}
