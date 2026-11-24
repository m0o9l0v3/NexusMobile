import Foundation

/// 経路確認要求の状態。
///
/// 受理した要求だけが案内先を更新する。同一点・失敗・地点の閲覧では案内を保持する（#85 M14）。
@MainActor
@Observable
final class RouteRequestStore {
    struct PreviewSession: Identifiable, Equatable {
        let id = UUID()
        let target: RoutePreviewTarget
        let requestedFrom: AppTab
    }

    private(set) var previewSession: PreviewSession?
    private(set) var previewResult: RoutePreview?

    private(set) var activeDestination: RouteDestination?
    var activeRoute: ResolvedRoute? { activeDestination?.resolvedRoute }
    private(set) var lastOutcome: RouteRequestOutcome?
    private(set) var lastAttemptedDestination: CanonicalSpotID?
    private(set) var lastAttemptedTab: AppTab?
    private(set) var isRequesting = false

    var keepsMapSnapshot: Bool { previewSession != nil || activeRoute != nil || isRequesting }

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
        lastAttemptedDestination = canonicalSpotID
        lastAttemptedTab = tab
        lastOutcome = outcome

        if case .accepted(let destination) = outcome {
            activeDestination = destination
        }
    }

    func presentPreview(for target: RoutePreviewTarget, from tab: AppTab) {
        previewResult = nil
        previewSession = PreviewSession(target: target, requestedFrom: tab)
    }

    func loadPreview(id: UUID, currentFix: LocationFix?, manualOrigin: RouteOrigin?) async {
        guard let session = previewSession, session.id == id, previewResult == nil, !Task.isCancelled else { return }
        let result = await handler.preview(fix: currentFix, manualOrigin: manualOrigin, destination: session.target.id,
                                           from: session.requestedFrom)
        guard previewSession?.id == id, !Task.isCancelled else { return }
        previewResult = result
    }

    func dismissPreview() {
        previewSession = nil
        previewResult = nil
    }

    /// プレビューと同じ経路を、再探索せずに案内へ引き継ぐ。
    func startPreviewedRoute(id: UUID) -> Bool {
        guard previewSession?.id == id, let result = previewResult, let destination = result.destination else { return false }
        // 案内開始後に、裏で進行していた経路要求の結果が上書きしないようにする。
        requestRevision += 1
        isRequesting = false
        activeDestination = destination
        dismissNotice()
        dismissPreview()
        return true
    }

    func endGuidance() {
        requestRevision += 1
        isRequesting = false
        activeDestination = nil
        dismissNotice()
    }

    func dismissNotice() {
        lastAttemptedDestination = nil
        lastAttemptedTab = nil
        lastOutcome = nil
    }

    /// 進行中の案内を明示的に終了する。閲覧操作からは呼ばない。
    func clearDestination() {
        activeDestination = nil
    }
}

extension RouteRequestOutcome {
    var allowsOriginSelectionRetry: Bool {
        switch self {
        case .samePoint, .routeFailure(.disconnected), .routeFailure(.unreachable),
             .routeFailure(.unknownOrigin), .routeFailure(.originNotRoutable):
            true
        case .unavailable(let message):
            message == RouteStateMessages.originRequired
        case .accepted, .unknownSpot, .routeFailure(.notRoutable):
            false
        }
    }
}
