import Foundation

enum RouteTurnDirection: Equatable, Sendable {
    case straight, slightRight, right, slightLeft, left, uTurn

    var instructionText: String {
        switch self {
        case .straight: "直進する"
        case .slightRight: "やや右へ進む"
        case .right: "右へ曲がる"
        case .slightLeft: "やや左へ進む"
        case .left: "左へ曲がる"
        case .uTurn: "折り返す"
        }
    }

    var systemImageName: String {
        switch self {
        case .straight: "arrow.up"
        case .slightRight: "arrow.up.right"
        case .right: "arrow.turn.up.right"
        case .slightLeft: "arrow.up.left"
        case .left: "arrow.turn.up.left"
        case .uTurn: "arrow.uturn.backward"
        }
    }
}

struct OutdoorRouteLandmark: Equatable, Sendable {
    enum Source: Int, Comparable, Equatable, Sendable {
        case landmark = 0, formalEntrance = 1, outdoorNode = 2

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let name: String
    let source: Source
}

struct OutdoorRouteStep: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        case depart(fromIndoor: Bool)
        case turn(RouteTurnDirection)
        case arrive(continuesIndoors: Bool)
    }

    enum VertexSource: Equatable, Sendable {
        case origin, edgeJunction, edgeInterior, destination
    }

    let id: String
    let index: Int
    let kind: Kind
    let vertexSource: VertexSource
    let coordinate: CampusMapCoordinate?
    let nodeID: String?
    let turnAngleDegrees: Double?
    let distanceMeters: Double?
    let landmark: OutdoorRouteLandmark?
    let passedLandmarks: [OutdoorRouteLandmark]
    let endpointLabel: String?

    var titleText: String {
        switch kind {
        case .depart(false): "\(endpointLabel ?? landmark?.name ?? "出発地")から進む"
        case .depart(true): (landmark?.name ?? endpointLabel).map { "\($0)から屋外へ進む" } ?? "屋外へ進む"
        case .turn(let direction): (landmark.map { "\($0.name)で" } ?? "") + direction.instructionText
        case .arrive(false): "\(endpointLabel ?? landmark?.name ?? "目的地")に到着"
        case .arrive(true): "\(landmark?.name ?? endpointLabel ?? "建物の入口")に到着（以降は屋内）"
        }
    }

    var landmarkNoteText: String? {
        switch kind {
        case .arrive(false):
            if let landmark, landmark.name != endpointLabel { return "目印：\(landmark.name)" }
        case .depart, .turn:
            if !passedLandmarks.isEmpty { return "通過：\(passedLandmarks.map(\.name).joined(separator: "、"))" }
        case .arrive(true): break
        }
        return nil
    }

    var distanceText: String? { distanceMeters.map(RouteSummaryFormatter.formatDistance(meters:)) }

    var systemImageName: String {
        switch kind {
        case .depart: "figure.walk"
        case .turn(let direction): direction.systemImageName
        case .arrive(false): "flag.checkered"
        case .arrive(true): "door.left.hand.open"
        }
    }
}

enum OutdoorRouteStepBuilder {
    /// 0.5 m 未満の重複・微細な揺れから、極端な曲がりを作らない。
    static let minimumSegmentMeters = 0.5
    /// 25°未満の小さな向きの変化は、同じ歩行指示にまとめる。
    static let straightMaxDegrees = 25.0
    /// 45°から明確な曲がり。検証経路の約48°と90°はともに右左折に当たる。
    static let slightTurnMaxDegrees = 45.0
    /// 150°以上は左右の差よりも来た方向へ戻ることを伝える。
    static let uTurnMinDegrees = 150.0

    private static func vector(from a: CampusMapCoordinate, to b: CampusMapCoordinate,
                               atLatitude latitude: Double) -> (x: Double, y: Double) {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * max(cos(latitude * .pi / 180), 1e-6)
        return ((b.longitude - a.longitude) * metersPerDegreeLongitude, (b.latitude - a.latitude) * metersPerDegreeLatitude)
    }

    static func signedTurnDegrees(from a: CampusMapCoordinate, via b: CampusMapCoordinate, to c: CampusMapCoordinate) -> Double? {
        signedTurnDegrees(incoming: (a, b), via: b, to: c)
    }

    // 接続ノードを共有する2辺でも、配信折れ線の端はわずかにずれることがある。
    // 各辺の実際の接線を同じ緯度に投影し、端点間のずれを進行方向に含めない。
    private static func signedTurnDegrees(incoming: (start: CampusMapCoordinate, end: CampusMapCoordinate),
                                          via b: CampusMapCoordinate, to c: CampusMapCoordinate) -> Double? {
        let u = vector(from: incoming.start, to: incoming.end, atLatitude: b.latitude)
        let v = vector(from: b, to: c, atLatitude: b.latitude)
        guard hypot(u.x, u.y) >= minimumSegmentMeters, hypot(v.x, v.y) >= minimumSegmentMeters else { return nil }
        let degrees = atan2(u.y * v.x - u.x * v.y, u.x * v.x + u.y * v.y) * 180 / .pi
        return abs(abs(degrees) - 180) < 1e-9 ? 180 : degrees
    }

    static func turnDirection(forSignedDegrees degrees: Double) -> RouteTurnDirection {
        let magnitude = abs(degrees)
        if magnitude < straightMaxDegrees { return .straight }
        if magnitude >= uTurnMinDegrees { return .uTurn }
        if magnitude < slightTurnMaxDegrees { return degrees > 0 ? .slightRight : .slightLeft }
        return degrees > 0 ? .right : .left
    }

    private static func name(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    static func landmarksByNodeID(in bundle: ParticipantBundle) -> [String: OutdoorRouteLandmark] {
        guard let features = bundle.map?.geojson.features else { return [:] }
        let spots = Dictionary(bundle.spots.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let buildings = Dictionary(features.filter { $0.featureType == "building" }.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })

        func entranceName(_ entrance: MapGeoJSON.Feature) -> String? {
            if let spot = name(spots[entrance.id]) { return spot }
            let building = entrance.buildingID.flatMap { name(spots[$0]) ?? name(buildings[$0]?.name) }
            guard let entrance = name(entrance.name) else { return building }
            if let building, !entrance.hasPrefix(building) { return "\(building) \(entrance)" }
            return entrance
        }

        var result: [String: OutdoorRouteLandmark] = [:]
        for feature in features {
            let node: String?, label: String?, source: OutdoorRouteLandmark.Source
            switch feature.featureType {
            case "landmark":
                (node, label, source) = (feature.accessNodeID, name(spots[feature.id]), .landmark)
            case "formal_entrance":
                (node, label, source) = (feature.outsideNodeID, entranceName(feature), .formalEntrance)
            case "outdoor_node":
                (node, label, source) = (feature.id, name(feature.name), .outdoorNode)
            default: continue
            }
            guard let node, name(node) != nil, let label else { continue }
            if let existing = result[node], (existing.source, existing.id) <= (source, feature.id) { continue }
            result[node] = .init(id: feature.id, name: label, source: source)
        }
        return result
    }

    /// 1つの指示の開始位置。次の曲がりまで歩いて距離と通過目印が決まってから表示モデルにする。
    private struct Instruction {
        let kind: OutdoorRouteStep.Kind
        let source: OutdoorRouteStep.VertexSource
        let coordinate: CampusMapCoordinate?
        let nodeID: String?
        var angle: Double?
        var label: String?
        var meters = 0.0
        var passed: [OutdoorRouteLandmark] = []

        func step(index: Int, landmarks: [String: OutdoorRouteLandmark]) -> OutdoorRouteStep {
            .init(id: "outdoor-step-\(index)", index: index, kind: kind, vertexSource: source, coordinate: coordinate,
                  nodeID: nodeID, turnAngleDegrees: angle, distanceMeters: source == .destination ? nil : meters,
                  landmark: nodeID.flatMap { landmarks[$0] }, passedLandmarks: passed, endpointLabel: label)
        }
    }

    private static func coordinates(of step: RouteStep) -> [CampusMapCoordinate] {
        step.coordinates.compactMap(CampusMapCoordinate.init(geoJSONPosition:)).filter {
            (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude)
        }
    }

    private static func length(from a: CampusMapCoordinate, to b: CampusMapCoordinate) -> Double {
        let delta = vector(from: a, to: b, atLatitude: (a.latitude + b.latitude) / 2)
        return hypot(delta.x, delta.y)
    }

    static func buildSteps(from path: RoutePath, originName: String? = nil, destinationName: String? = nil,
                           landmarksByNodeID landmarks: [String: OutdoorRouteLandmark] = [:]) -> [OutdoorRouteStep] {
        guard !path.isSamePoint else { return [] }
        let runs = path.steps.split { step in
            if case .walkingPath(.campus, _) = step.edge.kind { return false }
            return true
        }
        func includesIndoorBoundary(_ steps: ArraySlice<RouteStep>) -> Bool {
            steps.contains {
                switch $0.edge.kind {
                case .walkingPath(.indoor, _), .formalEntrance: true
                case .walkingPath(.campus, _), .transition: false
                }
            }
        }

        var result: [OutdoorRouteStep] = []
        for (i, run) in runs.enumerated() {
            // 正式入口の outside_node_id は接続する屋外辺の端点と同じ。室内の目的地名は入口に付けない。
            let previousEnd = i > 0 ? runs[i - 1].endIndex : path.steps.startIndex
            let nextStart = i + 1 < runs.count ? runs[i + 1].startIndex : path.steps.endIndex
            let startsIndoors = includesIndoorBoundary(path.steps[previousEnd..<run.startIndex])
            let endsIndoors = includesIndoorBoundary(path.steps[run.endIndex..<nextStart])
            appendRun(run, startsIndoors: startsIndoors, endsIndoors: endsIndoors,
                      originName: run.startIndex == path.steps.startIndex ? name(originName) : nil,
                      destinationName: run.endIndex == path.steps.endIndex ? name(destinationName) : nil, landmarks: landmarks, to: &result)
        }
        return result
    }

    private static func appendRun(_ run: ArraySlice<RouteStep>, startsIndoors: Bool, endsIndoors: Bool,
                                  originName: String?, destinationName: String?, landmarks: [String: OutdoorRouteLandmark],
                                  to result: inout [OutdoorRouteStep]) {
        guard let first = run.first, let last = run.last else { return }
        var current = Instruction(kind: .depart(fromIndoor: startsIndoors), source: .origin,
                                  coordinate: coordinates(of: first).first, nodeID: first.fromNodeID, label: originName)
        var seen = Set([landmarks[first.fromNodeID]?.id, landmarks[last.toNodeID]?.id].compactMap { $0 })
        var incoming: (start: CampusMapCoordinate, end: CampusMapCoordinate)?

        for edge in run {
            var points: [CampusMapCoordinate] = []
            var lengths: [Double] = []
            for point in coordinates(of: edge) {
                if let previous = points.last {
                    let meters = length(from: previous, to: point)
                    guard meters >= minimumSegmentMeters else { continue }
                    lengths.append(meters)
                }
                points.append(point)
            }

            let junction = landmarks[edge.fromNodeID]
            guard !lengths.isEmpty else {
                if let junction, seen.insert(junction.id).inserted { current.passed.append(junction) }
                current.meters += edge.edge.distanceMeters
                incoming = nil
                continue
            }
            let total = lengths.reduce(0, +)
            var remaining = edge.edge.distanceMeters
            for i in lengths.indices {
                let point = points[i]
                let nodeID = i == 0 ? edge.fromNodeID : nil
                let angle = incoming.flatMap { signedTurnDegrees(incoming: $0, via: point, to: points[i + 1]) }
                let direction = angle.map(turnDirection(forSignedDegrees:)) ?? .straight
                if direction != .straight {
                    result.append(current.step(index: result.count + 1, landmarks: landmarks))
                    current = Instruction(kind: .turn(direction), source: i == 0 ? .edgeJunction : .edgeInterior,
                                          coordinate: point, nodeID: nodeID, angle: angle)
                    if i == 0, let junction { seen.insert(junction.id) }
                } else if i == 0, let junction, seen.insert(junction.id).inserted {
                    current.passed.append(junction)
                }
                // 最後の線分には残額を割り当て、配信距離を按分時の丸めで失わない。
                let meters = i == lengths.count - 1 ? remaining : edge.edge.distanceMeters * (lengths[i] / total)
                current.meters += meters
                remaining -= meters
                incoming = (point, points[i + 1])
            }
        }
        result.append(current.step(index: result.count + 1, landmarks: landmarks))
        let arrival = Instruction(kind: .arrive(continuesIndoors: endsIndoors), source: .destination,
                                  coordinate: coordinates(of: last).last, nodeID: last.toNodeID, label: destinationName)
        result.append(arrival.step(index: result.count + 1, landmarks: landmarks))
    }
}
