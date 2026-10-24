import Foundation

extension CampusMapContent {
    /// 検証済みの bundle（E2-5 §5）から、描画面に渡す内容を組み立てる（#26）。
    ///
    /// - 建物：`map.geojson` の `building` Feature すべて。ラベルは `building.properties.name`。
    /// - ピン：`placement` のある spot すべて（bundle の順）。名前は `spots[].name`。
    ///   位置は `placement.point`、建物の spot は建物のラベルと同じ点。`placement` が null の spot は
    ///   置き場所が無いためピンを出さない（推測で埋めない、§5.2）。
    ///
    /// 建物には `placement.point` が無い（§5.2）ため、ラベルと建物のピンの位置は形状から描画用に計算する
    /// （`representativePoint`）。この値は bundle にも契約にも書き戻さない。
    init(bundle: ParticipantBundle) {
        var buildings: [Building] = []
        var buildingsByID: [String: Building] = [:]
        for feature in bundle.map?.geojson.features ?? [] where feature.featureType == "building" {
            guard case .polygon(let rings) = feature.geometry,
                  let outline = rings.first.flatMap(Self.openRing),
                  outline.count >= 3
            else {
                continue
            }
            let holes = rings.dropFirst().compactMap(Self.openRing).filter { $0.count >= 3 }
            let building = Building(
                id: feature.id,
                name: feature.name,
                outline: outline,
                holes: holes,
                labelCoordinate: Self.representativePoint(outline: outline, holes: holes)
            )
            buildings.append(building)
            buildingsByID[building.id] = building
        }

        var pins: [Pin] = []
        for spot in bundle.spots {
            guard let placement = spot.placement else { continue }
            let coordinate: CampusMapCoordinate?
            if let point = placement.point {
                coordinate = Self.coordinate(point)
            } else if placement.featureType == "building", let buildingID = placement.buildingID {
                coordinate = buildingsByID[buildingID]?.labelCoordinate
            } else {
                coordinate = nil
            }
            guard let coordinate else { continue }
            pins.append(Pin(spotID: CanonicalSpotID(rawValue: spot.id), name: spot.name, coordinate: coordinate))
        }

        self.init(buildings: buildings, pins: pins)
    }

    /// GeoJSON の position（`[経度, 緯度]`）。要素が足りなければ nil。
    private static func coordinate(_ position: [Double]) -> CampusMapCoordinate? {
        guard position.count >= 2 else { return nil }
        return CampusMapCoordinate(latitude: position[1], longitude: position[0])
    }

    /// GeoJSON の閉じた環から、閉じる点（最初と同じ最後の点）を除く。position が不正なら nil。
    private static func openRing(_ ring: [[Double]]) -> [CampusMapCoordinate]? {
        var coordinates: [CampusMapCoordinate] = []
        for position in ring {
            guard let coordinate = coordinate(position) else { return nil }
            coordinates.append(coordinate)
        }
        if coordinates.count > 1, coordinates.first == coordinates.last {
            coordinates.removeLast()
        }
        return coordinates
    }

    // MARK: - 建物のラベルの位置

    /// 建物の内側（穴の外）にある、ラベルを置く点。
    ///
    /// 外周の面積重心が内側にあればそれを使う。L字型などで外に出る場合は、重心と同じ緯度の水平線が
    /// 建物の内側を通る区間のうち最も長いものの中点を使う。構内の建物は小さいため、経緯度をそのまま
    /// 平面として扱う。どれも求まらない（形が潰れている）ときは外周の範囲の中心にする。
    static func representativePoint(
        outline: [CampusMapCoordinate],
        holes: [[CampusMapCoordinate]] = []
    ) -> CampusMapCoordinate {
        let rings = [outline] + holes
        let centroid = areaCentroid(outline)
        if let centroid, isInside(centroid, rings: rings) {
            return centroid
        }

        let bounds = outline.dropFirst().reduce(CampusMapBounds(outline[0])) { $0.including($1) }
        let latitude = centroid?.latitude ?? (bounds.minLatitude + bounds.maxLatitude) / 2
        if let longitude = widestInteriorMidpoint(atLatitude: latitude, rings: rings) {
            return CampusMapCoordinate(latitude: latitude, longitude: longitude)
        }
        return CampusMapCoordinate(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
    }

    /// 環の面積重心。面積が0なら nil。
    private static func areaCentroid(_ ring: [CampusMapCoordinate]) -> CampusMapCoordinate? {
        var doubleArea = 0.0
        var sumX = 0.0
        var sumY = 0.0
        for (index, current) in ring.enumerated() {
            let next = ring[(index + 1) % ring.count]
            let cross = current.longitude * next.latitude - next.longitude * current.latitude
            doubleArea += cross
            sumX += (current.longitude + next.longitude) * cross
            sumY += (current.latitude + next.latitude) * cross
        }
        guard abs(doubleArea) > .ulpOfOne else { return nil }
        return CampusMapCoordinate(latitude: sumY / (3 * doubleArea), longitude: sumX / (3 * doubleArea))
    }

    /// 偶奇規則で、外周の内側かつ穴の外にあるか。
    private static func isInside(_ point: CampusMapCoordinate, rings: [[CampusMapCoordinate]]) -> Bool {
        crossings(atLatitude: point.latitude, rings: rings)
            .filter { $0 > point.longitude }
            .count % 2 == 1
    }

    /// 水平線と各辺の交点の経度（昇順）。頂点を二重に数えないよう、辺の下端を含み上端を含まない。
    private static func crossings(atLatitude latitude: Double, rings: [[CampusMapCoordinate]]) -> [Double] {
        var longitudes: [Double] = []
        for ring in rings {
            for (index, start) in ring.enumerated() {
                let end = ring[(index + 1) % ring.count]
                let (low, high) = start.latitude <= end.latitude ? (start, end) : (end, start)
                guard low.latitude <= latitude, latitude < high.latitude else { continue }
                let ratio = (latitude - low.latitude) / (high.latitude - low.latitude)
                longitudes.append(low.longitude + ratio * (high.longitude - low.longitude))
            }
        }
        return longitudes.sorted()
    }

    /// 水平線が建物の内側を通る区間のうち、最も長いものの中点の経度。
    private static func widestInteriorMidpoint(atLatitude latitude: Double, rings: [[CampusMapCoordinate]]) -> Double? {
        let longitudes = crossings(atLatitude: latitude, rings: rings)
        var best: (width: Double, midpoint: Double)?
        for index in stride(from: 0, to: longitudes.count - 1, by: 2) {
            let width = longitudes[index + 1] - longitudes[index]
            if width > (best?.width ?? 0) {
                best = (width, (longitudes[index] + longitudes[index + 1]) / 2)
            }
        }
        return best?.midpoint
    }
}
