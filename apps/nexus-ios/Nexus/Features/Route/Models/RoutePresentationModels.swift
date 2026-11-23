import Foundation

enum RouteOrigin: Equatable, Sendable {
    case destination(CanonicalSpotID, approach: RoutingApproach = .fromOutdoor)
    case node(id: String, displayName: String? = nil)
}

struct RouteEndpoint: Equatable, Sendable {
    let id: String
    let displayName: String?
    let coordinate: CampusMapCoordinate?

    var label: String { displayName ?? id }
}

struct RoutePolylineSegment: Equatable, Sendable, Identifiable {
    enum Scope: Equatable, Sendable {
        case outdoor
        case indoor(buildingID: String, floorID: String)
    }

    let id: String
    let scope: Scope
    let coordinates: [CampusMapCoordinate]
}

struct ResolvedRoute: Equatable, Sendable {
    let requestID: UUID
    let origin: RouteEndpoint
    let destination: RouteEndpoint
    let path: RoutePath
    let segments: [RoutePolylineSegment]
    let traversedFloorLabels: [String]
    let outdoorSteps: [OutdoorRouteStep]
    let bundleVersion: Int64?

    init(requestID: UUID = UUID(), origin: RouteEndpoint, destination: RouteEndpoint, path: RoutePath,
         segments: [RoutePolylineSegment], traversedFloorLabels: [String], bundleVersion: Int64?,
         outdoorSteps: [OutdoorRouteStep] = []) {
        self.requestID = requestID
        self.origin = origin
        self.destination = destination
        self.path = path
        self.segments = segments
        self.traversedFloorLabels = traversedFloorLabels
        self.outdoorSteps = outdoorSteps
        self.bundleVersion = bundleVersion
    }

    var totalDistanceMeters: Double { path.totalDistanceMeters }
    var totalEstimatedSeconds: Double { path.totalEstimatedSeconds }
    var allCoordinates: [CampusMapCoordinate] { segments.flatMap(\.coordinates) }
    var hasIndoorSteps: Bool { !path.traversedFloorIDs.isEmpty }
}

struct RouteSamePoint: Equatable, Sendable {
    let destinationSpotID: CanonicalSpotID
    let displayName: String?
    let nodeID: String
}

enum RouteFailurePresentation: Equatable, Sendable {
    case disconnected(destinationID: CanonicalSpotID, destinationName: String?)
    case unreachable(destinationID: CanonicalSpotID, destinationName: String?)
    case notRoutable(RouteFailureReason.NotRoutable, destinationID: CanonicalSpotID, destinationName: String?)
    case unknownOrigin(String)
    case originNotRoutable(RouteFailureReason.NotRoutable)

    var title: String {
        switch self {
        case .disconnected: "目的地までの経路がつながっていません"
        case .unreachable: "通行できる経路がありません"
        case .notRoutable: "この目的地は経路案内の対象外です"
        case .unknownOrigin: "出発地が登録されていません"
        case .originNotRoutable: "この出発地は経路案内の対象外です"
        }
    }

    var detail: String {
        switch self {
        case let .disconnected(id, name):
            "出発地と「\(name ?? id.rawValue)」を結ぶ歩行経路は未接続です。直線での案内は行いません。"
        case let .unreachable(id, name):
            "通行方向や通行条件により「\(name ?? id.rawValue)」へは到達できません。直線での案内は行いません。"
        case let .notRoutable(reason, id, name):
            "「\(name ?? id.rawValue)」の\(Self.accessDetail(reason))"
        case .unknownOrigin(let id):
            "指定された出発地「\(id)」が経路データにありません。"
        case .originNotRoutable(let reason):
            "出発地の\(Self.accessDetail(reason))"
        }
    }

    var systemImageName: String {
        switch self {
        case .disconnected: "point.topleft.down.curvedto.point.bottomright.up"
        case .unreachable: "exclamationmark.triangle"
        case .notRoutable, .originNotRoutable: "mappin.slash"
        case .unknownOrigin: "questionmark.circle"
        }
    }

    private static func accessDetail(_ reason: RouteFailureReason.NotRoutable) -> String {
        switch reason {
        case .missingAccessNode: "経路との接続地点が未設定です。"
        case .invalidAccessNode: "経路との接続地点が正しく登録されていません。"
        case .ambiguousPrimaryEntrance: "代表入口が複数登録されています。"
        }
    }
}

enum RoutePolylineBuilder {
    static func buildSegments(from path: RoutePath, nodeCoordinates: [String: CampusMapCoordinate] = [:]) -> [RoutePolylineSegment] {
        var segments: [RoutePolylineSegment] = []
        var scope: RoutePolylineSegment.Scope?
        var points: [CampusMapCoordinate] = []

        func finish() {
            if let scope, points.count >= 2 {
                segments.append(.init(id: "segment-\(segments.count)", scope: scope, coordinates: points))
            }
            points = []
            scope = nil
        }

        func append(_ coordinates: [CampusMapCoordinate], in nextScope: RoutePolylineSegment.Scope) {
            if scope != nextScope { finish() }
            scope = nextScope
            for point in coordinates where point != points.last {
                points.append(point)
            }
        }

        for step in path.steps {
            let coordinates = step.coordinates.compactMap(CampusMapCoordinate.init(geoJSONPosition:))
            switch step.edge.kind {
            case .walkingPath(let location, _):
                guard !coordinates.isEmpty else { finish(); continue }
                switch location {
                case .campus: append(coordinates, in: .outdoor)
                case let .indoor(building, floor): append(coordinates, in: .indoor(buildingID: building, floorID: floor))
                }
            case let .formalEntrance(building, floor, _, _, _):
                guard let threshold = coordinates.first else { finish(); continue }
                let indoor = RoutePolylineSegment.Scope.indoor(buildingID: building, floorID: floor)
                // 閾値を両側に含める。入口だけの経路にも、両端のノードから閾値までの形がある。
                append([nodeCoordinates[step.fromNodeID], threshold].compactMap { $0 },
                       in: step.isReversed ? indoor : .outdoor)
                append([threshold, nodeCoordinates[step.toNodeID]].compactMap { $0 },
                       in: step.isReversed ? .outdoor : indoor)
            case .transition:
                // 階層間の遷移には配信上の描画面が未定義。離れた廊下の間を線で結ばない。
                finish()
            }
        }
        finish()
        return segments
    }
}

extension CampusMapCoordinate {
    init?(geoJSONPosition position: [Double]) {
        guard position.count >= 2, position[0].isFinite, position[1].isFinite else { return nil }
        self.init(latitude: position[1], longitude: position[0])
    }
}

enum RouteSummaryFormatter {
    private static let locale = Locale(identifier: "ja_JP_POSIX")

    static func formatDistance(meters: Double) -> String {
        guard meters.isFinite, meters >= 0 else { return "—" }
        if meters == 0 { return "0 m" }
        if meters.rounded() < 1000 { return "\(max(1, Int(meters.rounded()))) m" }
        return String(format: "%.1f km", locale: locale, (meters / 100).rounded() / 10)
    }

    static func formatWalkingDuration(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds == 0 { return "0分" }
        if seconds < 60 { return "1分未満" }
        let minutes = (seconds / 60).rounded()
        if minutes < 60 { return "約\(Int(minutes))分" }
        let hours = String(format: "%.0f", locale: locale, floor(minutes / 60))
        let remainder = Int(minutes.truncatingRemainder(dividingBy: 60))
        return remainder == 0 ? "約\(hours)時間" : "約\(hours)時間\(remainder)分"
    }
}

enum RouteAccessibilityText {
    static func distance(_ route: ResolvedRoute) -> String {
        "距離、\(RouteSummaryFormatter.formatDistance(meters: route.totalDistanceMeters))"
    }

    static func walkingDuration(_ route: ResolvedRoute) -> String {
        "徒歩の目安、\(RouteSummaryFormatter.formatWalkingDuration(seconds: route.totalEstimatedSeconds))"
    }

    static func marker(_ endpoint: RouteEndpoint, isOrigin: Bool) -> String {
        "\(isOrigin ? "出発地" : "目的地")、\(endpoint.label)"
    }

    static func outdoorStep(_ step: OutdoorRouteStep, totalCount: Int) -> String {
        ["全\(totalCount)件中\(step.index)件目", step.titleText, step.distanceText, step.landmarkNoteText]
            .compactMap { $0 }.joined(separator: "、")
    }

    static func outdoorStepsToggle(count: Int) -> String {
        "屋外のステップ、\(count)件"
    }

    static func started(_ route: ResolvedRoute) -> String {
        "\(route.destination.label)への案内を開始しました。\(walkingDuration(route))、\(distance(route))。"
    }

    static let ended = "経路案内を終了しました。"

    static func announcement(for outcome: RouteRequestOutcome) -> String? {
        switch outcome {
        case .routeFailure(let failure): "\(failure.title)。\(failure.detail)"
        case .samePoint(let point): "出発地と「\(point.displayName ?? point.destinationSpotID.rawValue)」は同じ地点です。"
        case .unavailable(let message): message.title
        case .unknownSpot(let id): "「\(id.rawValue)」は経路データに登録されていません"
        case .accepted: nil
        }
    }
}

enum CampusMapRouteCamera {
    static func region(for route: ResolvedRoute, reservesSpaceAboveMarkers: Bool = false) -> CampusMapFocus.Region? {
        let points = route.allCoordinates + [route.origin.coordinate, route.destination.coordinate].compactMap { $0 }
        guard let first = points.first else { return nil }
        let bounds = points.dropFirst().reduce(CampusMapBounds(first)) { $0.including($1) }
        let lat = max((bounds.maxLatitude - bounds.minLatitude) * (reservesSpaceAboveMarkers ? 2.6 : 1.8), 0.0012)
        let lon = max((bounds.maxLongitude - bounds.minLongitude) * 1.5, 0.0012)
        // 大きな文字では経路カードの分だけ地図が低くなるため、上側にもピンとカプセルの余白を取る。
        let latitudeOffset = lat * (reservesSpaceAboveMarkers ? 0.08 : -0.12)
        return .init(center: .init(latitude: (bounds.minLatitude + bounds.maxLatitude) / 2 + latitudeOffset,
                                   longitude: (bounds.minLongitude + bounds.maxLongitude) / 2),
                     latitudeDelta: lat, longitudeDelta: lon)
    }
}
