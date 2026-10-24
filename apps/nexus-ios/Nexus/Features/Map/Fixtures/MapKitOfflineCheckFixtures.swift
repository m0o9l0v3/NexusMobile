#if DEBUG
import Foundation

/// #24 の通信断の表示確認に使う検証用データ。正式な地図データではない。
///
/// 建物の canonical ID と表示名は E1-1 の14棟だが、形状と位置は格子状に並べた仮のもので、
/// 実際の建物の形・配置とは一致しない。基準の座標は `map-dataset-geojson-v2.example.json` の付近。
extension CampusMapContent {
    static let offlineCheckNotice = "検証用の仮配置（正式な地図データではありません）"

    static let offlineCheck: CampusMapContent = {
        let names: [(id: String, name: String)] = [
            ("ab", "管理棟"),
            ("amh", "女子寮"),
            ("aptr", "機体実習室"),
            ("ar", "アリーナ"),
            ("ctc_main", "CTC"),
            ("ctc2", "CTC2"),
            ("dh", "食堂"),
            ("dvh", "Da Vinci Hall"),
            ("hgr_a", "格納庫A"),
            ("hgr_b", "格納庫B"),
            ("lbh", "男子寮"),
            ("mb", "教室棟"),
            ("ptb", "実習棟"),
            ("sab", "技能審査棟"),
        ]

        let originLatitude = 42.7700
        let originLongitude = 141.6790
        let columns = 5
        let width = 0.0007
        let height = 0.00035
        let columnStep = 0.0011
        let rowStep = 0.0012

        var buildings: [Building] = []
        var pins: [Pin] = []
        for (index, entry) in names.enumerated() {
            let west = originLongitude + Double(index % columns) * columnStep
            let south = originLatitude + Double(index / columns) * rowStep
            let east = west + width
            let north = south + height
            let centerLongitude = (west + east) / 2

            buildings.append(Building(
                id: entry.id,
                name: entry.name,
                outline: [
                    CampusMapCoordinate(latitude: south, longitude: west),
                    CampusMapCoordinate(latitude: south, longitude: east),
                    CampusMapCoordinate(latitude: north, longitude: east),
                    CampusMapCoordinate(latitude: north, longitude: west),
                ],
                labelCoordinate: CampusMapCoordinate(latitude: (south + north) / 2, longitude: centerLongitude)
            ))
            // 建物の Spot のピン。ピンは座標の上に立つため、ラベルと重ならないよう南の辺から離して置く。
            pins.append(Pin(
                spotID: CanonicalSpotID(rawValue: entry.id),
                name: entry.name,
                coordinate: CampusMapCoordinate(latitude: south - 0.0003, longitude: centerLongitude)
            ))
        }

        // 部屋（教室棟の中）とランドマークのピン。建物以外の種類も同じ描き方で出ることの確認用。
        pins.append(Pin(
            spotID: CanonicalSpotID(rawValue: "mb_1f_cl_001"),
            name: "検証用の教室",
            coordinate: CampusMapCoordinate(latitude: 42.77260, longitude: 141.68025)
        ))
        pins.append(Pin(
            spotID: CanonicalSpotID(rawValue: "campus_lm_001"),
            name: "検証用のランドマーク",
            coordinate: CampusMapCoordinate(latitude: 42.77330, longitude: 141.67900)
        ))

        return CampusMapContent(buildings: buildings, pins: pins)
    }()
}
#endif
