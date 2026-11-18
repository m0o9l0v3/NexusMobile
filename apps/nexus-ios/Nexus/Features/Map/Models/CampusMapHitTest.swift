import Foundation

/// 地図のタップから建物を選ぶ判定（E1-4 改訂4 §6、改訂3 §4.2）。
///
/// Nexus の建物の形は独立した資料から作り、Apple の地図には合わせないため、Apple の建物とは
/// 数 m ずれる（改訂4 §1）。利用者は Apple の建物の端をタップすることがあるので、形をそのまま
/// 判定に使わず、形から `toleranceMeters` 以内のタップも当たりとする（形を広げて判定する）。
///
/// 選び方（同じ入力なら常に同じ建物を選ぶ）：
/// 1. 形の内側（穴の中を除く）のタップは距離 0、外側は形の縁までの最短距離。
/// 2. 距離が `toleranceMeters` 以下の建物だけを候補にする。
/// 3. 距離が最も小さい建物を選ぶ。隣り合う2棟の広げた範囲が重なるときは、近いほうの建物になる。
/// 4. 距離が同じ（`tieMeters` 以内）なら、面積の小さい建物を選ぶ。形が重なっているとき
///    （大きな建物の中に小さな建物がある）、小さい建物は内側をタップしないと選べないため。
/// 5. それも同じなら、建物 ID の辞書順で先のもの。
///
/// 距離は、タップした地点を原点とする平面（東西・南北のメートル）に写して計算する。
/// 構内（数百 m）の範囲では、この近似の誤差は数 cm に収まる。
enum CampusMapHitTest {
    /// 形を広げる幅の下限（m）。ずれ（2〜4 m）より少し大きくする。
    static let minimumToleranceMeters = 5.0

    /// 指で押せる範囲の半径（pt）。HIG の最小タップ領域 44pt の半分。
    static let fingerRadiusPoints = 22.0

    /// 同じ距離とみなす差（m）。
    static let tieMeters = 0.01

    /// その縮尺での広げる幅（m）。引いた縮尺では、指の大きさ（22pt）に当たる距離まで広げる。
    /// 寄った縮尺でも `minimumToleranceMeters` より狭くしない。
    static func toleranceMeters(metersPerPoint: Double) -> Double {
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return minimumToleranceMeters }
        return max(minimumToleranceMeters, fingerRadiusPoints * metersPerPoint)
    }

    /// タップした地点で選ぶ建物。どの建物からも `toleranceMeters` より遠ければ nil。
    static func building(
        at point: CampusMapCoordinate,
        in buildings: [CampusMapContent.Building],
        toleranceMeters: Double
    ) -> CampusMapContent.Building? {
        let projection = LocalProjection(origin: point)
        var best: (building: CampusMapContent.Building, distance: Double, area: Double)?
        for building in buildings {
            guard building.outline.count >= 3 else { continue }
            let outline = building.outline.map(projection.project)
            let holes = building.holes.filter { $0.count >= 3 }.map { $0.map(projection.project) }
            let distance = distanceFromOrigin(toOutline: outline, holes: holes)
            guard distance <= toleranceMeters else { continue }
            let area = abs(signedArea(outline)) - holes.reduce(0) { $0 + abs(signedArea($1)) }
            if let current = best {
                if distance < current.distance - tieMeters {
                    best = (building, distance, area)
                } else if abs(distance - current.distance) <= tieMeters {
                    if area < current.area - 0.01 || (abs(area - current.area) <= 0.01 && building.id < current.building.id) {
                        best = (building, distance, area)
                    }
                }
            } else {
                best = (building, distance, area)
            }
        }
        return best?.building
    }

    /// 建物を選んだときに開く地点（建物の Spot）。
    /// `placement.feature_type` が building で、その建物に所在するピン。無ければ、建物と同じ
    /// canonical ID のピン。どちらも無ければ nil（建物の Spot が公開されていない）。
    static func spotID(forBuilding building: CampusMapContent.Building, in content: CampusMapContent) -> CanonicalSpotID? {
        if let pin = content.pins.first(where: { $0.kind == .building && $0.buildingID == building.id }) {
            return pin.spotID
        }
        return content.pins.first { $0.spotID.rawValue == building.id }?.spotID
    }

    /// タップした地点で選ぶ地点。建物を選び、その建物の Spot を返す。
    static func spotID(
        at point: CampusMapCoordinate,
        in content: CampusMapContent,
        toleranceMeters: Double
    ) -> CanonicalSpotID? {
        // 建物の Spot が公開されていない建物は、候補から外して次に近い建物を探す。
        let selectable = content.buildings.filter { spotID(forBuilding: $0, in: content) != nil }
        return building(at: point, in: selectable, toleranceMeters: toleranceMeters)
            .flatMap { spotID(forBuilding: $0, in: content) }
    }

    // MARK: - 平面の計算

    struct Point: Equatable {
        let x: Double
        let y: Double
    }

    /// 緯度経度を、原点からの東西（x）・南北（y）のメートルに写す。
    struct LocalProjection {
        static let metersPerDegreeLatitude = 111_320.0

        let origin: CampusMapCoordinate
        let metersPerDegreeLongitude: Double

        init(origin: CampusMapCoordinate) {
            self.origin = origin
            metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)
        }

        func project(_ coordinate: CampusMapCoordinate) -> Point {
            Point(
                x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
                y: (coordinate.latitude - origin.latitude) * Self.metersPerDegreeLatitude
            )
        }
    }

    /// 原点（タップした地点）から形までの距離。形の内側（穴の中を除く）なら 0。
    static func distanceFromOrigin(toOutline outline: [Point], holes: [[Point]]) -> Double {
        let origin = Point(x: 0, y: 0)
        let insideOutline = contains(origin, ring: outline)
        let enclosingHole = holes.first { contains(origin, ring: $0) }
        if insideOutline && enclosingHole == nil {
            return 0
        }
        if let enclosingHole {
            // 中庭の中。中庭の縁（＝建物の縁）までの距離。
            return distanceFromOrigin(toRing: enclosingHole)
        }
        return distanceFromOrigin(toRing: outline)
    }

    /// 偶奇判定。縁の上はどちらになるかを決めない（縁の上は距離 0 として別に扱われる）。
    static func contains(_ point: Point, ring: [Point]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i]
            let b = ring[j]
            if (a.y > point.y) != (b.y > point.y) {
                let crossingX = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
                if point.x < crossingX {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    static func distanceFromOrigin(toRing ring: [Point]) -> Double {
        var best = Double.infinity
        for i in ring.indices {
            let a = ring[i]
            let b = ring[(i + 1) % ring.count]
            best = min(best, distanceFromOrigin(toSegment: a, b))
        }
        return best
    }

    static func distanceFromOrigin(toSegment a: Point, _ b: Point) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(a.x, a.y) }
        // 原点を線分へ下ろした足の位置（0...1 に収める）。
        let t = min(max(-(a.x * dx + a.y * dy) / lengthSquared, 0), 1)
        return hypot(a.x + t * dx, a.y + t * dy)
    }

    /// 符号付きの面積（m²）。向きは問わないので絶対値で使う。
    static func signedArea(_ ring: [Point]) -> Double {
        var sum = 0.0
        for i in ring.indices {
            let a = ring[i]
            let b = ring[(i + 1) % ring.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }
}
