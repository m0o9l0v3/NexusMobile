import CoreLocation

/// MapKit の描画面（`MapKitMapSurfaceView`）が描く内容。
///
/// 外部タイルに頼らず、建物の形・ラベル・ピンをすべてアプリ側で描くための入力（M1-5、#24）。
/// bundle の `map.geojson`・`spots[]` からは `init(bundle:)` で組み立てる（#26）。
struct CampusMapContent: Equatable, Sendable {
    let buildings: [Building]
    let pins: [Pin]

    /// 建物の形状とラベル。ラベルは `building.properties.name`（E2-5 §5.2、M1 決定記録 §5.1 の1）。
    struct Building: Equatable, Sendable, Identifiable {
        let id: String
        /// ラベルにする名前。無ければラベルを出さない（ID などで埋めない）。
        let name: String?
        /// 外周。GeoJSON の Polygon の外側の環で、閉じる点（最初と同じ点）は含めない。
        let outline: [CampusMapCoordinate]
        /// 中庭などの穴（Polygon の内側の環、E1-4）。閉じる点は含めない。
        let holes: [[CampusMapCoordinate]]
        /// ラベルと、建物の Spot のピンを置く位置。描画のためだけの値で、bundle には書き戻さない。
        let labelCoordinate: CampusMapCoordinate

        init(
            id: String,
            name: String?,
            outline: [CampusMapCoordinate],
            holes: [[CampusMapCoordinate]] = [],
            labelCoordinate: CampusMapCoordinate
        ) {
            self.id = id
            self.name = name
            self.outline = outline
            self.holes = holes
            self.labelCoordinate = labelCoordinate
        }
    }

    /// 地点のピン。名前は `spots[].name`（E2-5 §5.2 の表示名の正本）で、建物のラベルとは別に持つ。
    struct Pin: Equatable, Sendable, Identifiable {
        let spotID: CanonicalSpotID
        let name: String
        let coordinate: CampusMapCoordinate

        var id: String { spotID.rawValue }
    }

    /// すべての形状とピンを収める範囲。最初の表示位置に使う。空なら nil。
    var bounds: CampusMapBounds? {
        let coordinates = buildings.flatMap(\.outline) + pins.map(\.coordinate)
        guard let first = coordinates.first else { return nil }
        return coordinates.dropFirst().reduce(CampusMapBounds(first)) { $0.including($1) }
    }
}

/// 緯度経度（WGS84、E1-5）。GeoJSON の `[経度, 緯度]` の並びとは逆の名前付きで持つ。
struct CampusMapCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CampusMapBounds: Equatable, Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    init(_ coordinate: CampusMapCoordinate) {
        minLatitude = coordinate.latitude
        maxLatitude = coordinate.latitude
        minLongitude = coordinate.longitude
        maxLongitude = coordinate.longitude
    }

    private init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    func including(_ coordinate: CampusMapCoordinate) -> CampusMapBounds {
        CampusMapBounds(
            minLatitude: min(minLatitude, coordinate.latitude),
            maxLatitude: max(maxLatitude, coordinate.latitude),
            minLongitude: min(minLongitude, coordinate.longitude),
            maxLongitude: max(maxLongitude, coordinate.longitude)
        )
    }

    func contains(_ coordinate: CampusMapCoordinate) -> Bool {
        (minLatitude...maxLatitude).contains(coordinate.latitude)
            && (minLongitude...maxLongitude).contains(coordinate.longitude)
    }
}
