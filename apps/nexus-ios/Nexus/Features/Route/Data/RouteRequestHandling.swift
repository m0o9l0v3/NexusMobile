import Foundation

/// 進行中の経路案内の目的地。
struct RouteDestination: Equatable, Sendable {
    let canonicalSpotID: CanonicalSpotID
    /// どのタブから要求されたか。案内の再開導線を出すために保持する。
    let requestedFrom: AppTab
    let resolvedRoute: ResolvedRoute?
    let savedMetadata: NexusSavedMetadata?

    init(canonicalSpotID: CanonicalSpotID, requestedFrom: AppTab, resolvedRoute: ResolvedRoute? = nil,
         savedMetadata: NexusSavedMetadata? = nil) {
        self.canonicalSpotID = canonicalSpotID
        self.requestedFrom = requestedFrom
        self.resolvedRoute = resolvedRoute
        self.savedMetadata = savedMetadata
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

    var loadPreview: (@Sendable (LocationFix?, RouteOrigin?, CanonicalSpotID, AppTab) async -> RoutePreview)?

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

    func preview(fix: LocationFix?, manualOrigin: RouteOrigin?, destination: CanonicalSpotID, from tab: AppTab) async -> RoutePreview {
        if let loadPreview {
            return await loadPreview(fix, manualOrigin, destination, tab)
        }
        return RoutePreview(outcome: await resolve(origin: manualOrigin, destination: destination, from: tab))
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

extension RouteRequestOutcome {
    var statusMessage: NexusStateMessage {
        .init(title: title, detail: detail, systemImageName: systemImageName)
    }

    private var title: String {
        switch self {
        case .samePoint:
            return "出発地と目的地は同じ地点です"
        case .routeFailure(let failure):
            return failure.title
        case .accepted(let destination):
            if let route = destination.resolvedRoute { return "\(route.destination.label)への経路" }
            return "「\(destination.canonicalSpotID.rawValue)」への経路を目的地に設定しました"
        case .unknownSpot(let canonicalSpotID):
            return "「\(canonicalSpotID.rawValue)」は経路データに登録されていません"
        case .unavailable(let message):
            return message.title
        }
    }

    private var detail: String? {
        switch self {
        case .accepted(let destination):
            guard let route = destination.resolvedRoute else { return nil }
            let time = RouteSummaryFormatter.formatWalkingDuration(seconds: route.totalEstimatedSeconds)
            let distance = RouteSummaryFormatter.formatDistance(meters: route.totalDistanceMeters)
            return "徒歩 \(time)（目安）・\(distance)。マップタブで確認できます。"
        case .samePoint(let point):
            return "「\(point.displayName ?? point.destinationSpotID.rawValue)」は出発地と同じ接続地点です。"
        case .routeFailure(let failure):
            return failure.detail
        case .unknownSpot:
            // 別地点へ置換しない。何が起きたかだけを伝える。
            return "別の地点への案内は開始しません。地点の登録後に利用できます。"
        case .unavailable(let message):
            return message.detail
        }
    }

    private var systemImageName: String {
        switch self {
        case .samePoint:
            return "mappin.circle"
        case .routeFailure(let failure):
            return failure.systemImageName
        case .accepted:
            return "checkmark.circle"
        case .unknownSpot:
            return "questionmark.circle"
        case .unavailable(let message):
            return message.systemImageName
        }
    }
}
