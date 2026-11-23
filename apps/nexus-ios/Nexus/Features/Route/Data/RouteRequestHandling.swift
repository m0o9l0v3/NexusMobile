import Foundation

/// 進行中の経路案内の目的地。
struct RouteDestination: Equatable, Sendable {
    let canonicalSpotID: CanonicalSpotID
    /// どのタブから要求されたか。案内の再開導線を出すために保持する。
    let requestedFrom: AppTab
    let resolvedRoute: ResolvedRoute?

    init(canonicalSpotID: CanonicalSpotID, requestedFrom: AppTab, resolvedRoute: ResolvedRoute? = nil) {
        self.canonicalSpotID = canonicalSpotID
        self.requestedFrom = requestedFrom
        self.resolvedRoute = resolvedRoute
    }
}

/// 経路確認要求の結果。
///
/// 「経路が出せない」は異常ではなく**表示すべき通常の結果**なので、
/// `throw` ではなくこの列挙で返す。
enum RouteRequestOutcome: Equatable, Sendable {
    case accepted(RouteDestination)
    case samePoint(RouteSamePoint)
    case routeFailure(RouteFailurePresentation)
    /// 指定 canonical ID が経路データに存在しない。別地点へ置換しない。
    case unknownSpot(CanonicalSpotID)
    case unavailable(NexusStateMessage)
}

/// 経路確認の注入境界。出発地を省略した既存の呼び出しも同じ解決処理を使う。
struct RouteRequestHandling: Sendable {
    private var requestRouteWithOrigin: @Sendable (RouteOrigin?, CanonicalSpotID, AppTab) async -> RouteRequestOutcome

    var requestRoute: @Sendable (CanonicalSpotID, AppTab) async -> RouteRequestOutcome {
        get { { [requestRouteWithOrigin] id, tab in await requestRouteWithOrigin(nil, id, tab) } }
        set { requestRouteWithOrigin = { _, id, tab in await newValue(id, tab) } }
    }

    init(requestRouteWithOrigin: @escaping @Sendable (RouteOrigin?, CanonicalSpotID, AppTab) async -> RouteRequestOutcome) {
        self.requestRouteWithOrigin = requestRouteWithOrigin
    }

    func resolve(origin: RouteOrigin? = nil, destination: CanonicalSpotID, from tab: AppTab) async -> RouteRequestOutcome {
        await requestRouteWithOrigin(origin, destination, tab)
    }

    init(requestRoute: @escaping @Sendable (CanonicalSpotID, AppTab) async -> RouteRequestOutcome) {
        self.requestRouteWithOrigin = { _, id, tab in await requestRoute(id, tab) }
    }
}

extension RouteRequestHandling {
    /// 本番の既定値。経路データが接続されるまでは常に未提供を返す。
    static let unconfigured = RouteRequestHandling { _, _ in
        .unavailable(
            NexusStateMessage(
                title: "経路案内は未提供です",
                detail: "経路データの接続後に利用できます。",
                systemImageName: "point.topleft.down.curvedto.point.filled.bottomright.up"
            )
        )
    }
}
