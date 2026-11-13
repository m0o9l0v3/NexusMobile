import Foundation
@testable import Nexus

/// E2-5 §5 の形の bundle を試験用に組み立てる。
///
/// ID は E1-7（部屋）と E1-4 改訂1（`room` / `landmark`）の規則に従う。
/// 旧 ID（`mb_f2_cr_2a` など）は使わない（E2-5 O-3a）。値は形式を示すためのもので、実データではない。
enum BundleFixtures {
    static func spot(
        id: String,
        name: String,
        kind: Any = NSNull(),
        placement: Any = NSNull()
    ) -> [String: Any] {
        [
            "id": id,
            "name": name,
            "kind": kind,
            "description": NSNull(),
            "search_aliases": [],
            "utilization": "available",
            "placement": placement,
        ]
    }

    static func placement(
        featureType: String,
        buildingID: Any,
        floorID: Any = NSNull(),
        point: Any = NSNull(),
        accessNodeID: Any = NSNull()
    ) -> [String: Any] {
        [
            "feature_type": featureType,
            "building_id": buildingID,
            "floor_id": floorID,
            "point": point,
            "access_node_id": accessNodeID,
        ]
    }

    static let roomPoint: [Double] = [141.622751, 42.784338]
    static let landmarkPoint: [Double] = [141.622500, 42.785000]

    /// 教室棟（建物）、2F の教室（room）、ランドマーク（landmark）と、到達ノードを1つ持つ地図。
    static func geojson(schemaVersion: String = "2.0.0", extraFeatures: [[String: Any]] = []) -> [String: Any] {
        let features: [[String: Any]] = [
            [
                "type": "Feature",
                "id": "mb",
                "geometry": [
                    "type": "Polygon",
                    "coordinates": [[[141.6227, 42.7843], [141.6229, 42.7843], [141.6229, 42.7845], [141.6227, 42.7843]]],
                ],
                "properties": ["feature_type": "building", "name": "教室棟"],
            ],
            [
                "type": "Feature",
                "id": "mb_2f_cl_001",
                "geometry": ["type": "Point", "coordinates": roomPoint],
                "properties": [
                    "feature_type": "room",
                    "building_id": "mb",
                    "floor_id": "mb_2f",
                    "room_type": "cl",
                    "access_node_id": "mb_2f_n_012",
                ],
            ],
            [
                "type": "Feature",
                "id": "mb_2f_n_012",
                "geometry": ["type": "Point", "coordinates": roomPoint],
                "properties": [
                    "feature_type": "indoor_node",
                    "building_id": "mb",
                    "floor_id": "mb_2f",
                    "node_kind": "destination",
                ],
            ],
            [
                "type": "Feature",
                "id": "campus_lm_001",
                "geometry": ["type": "Point", "coordinates": landmarkPoint],
                "properties": ["feature_type": "landmark", "scope": "campus"],
            ],
        ] + extraFeatures

        return [
            "type": "FeatureCollection",
            "nexus": [
                "schema_version": schemaVersion,
                "floors": [["id": "mb_2f", "building_id": "mb", "name": "2F"]],
            ],
            "features": features,
        ]
    }

    static func validSpots() -> [[String: Any]] {
        [
            spot(
                id: "mb_2f_cl_001",
                name: "2A教室",
                kind: "classroom",
                placement: placement(
                    featureType: "room",
                    buildingID: "mb",
                    floorID: "mb_2f",
                    point: roomPoint,
                    accessNodeID: "mb_2f_n_012"
                )
            ),
            spot(
                id: "mb",
                name: "教室棟",
                placement: placement(featureType: "building", buildingID: "mb")
            ),
            spot(
                id: "campus_lm_001",
                name: "航空神社",
                kind: "facility",
                placement: placement(featureType: "landmark", buildingID: NSNull(), point: landmarkPoint)
            ),
        ]
    }

    static func bundleObject(
        version: Int64 = 42,
        schemaVersion: String = "2.0.0",
        spots: [[String: Any]]? = nil,
        idAliases: [[String: Any]] = [],
        map: Any? = nil
    ) -> [String: Any] {
        [
            "nexus_bundle": [
                "schema_version": schemaVersion,
                "bundle_version": version,
                "release_id": "0192f0a1-0000-7000-8000-000000000042",
                "published_at": "2026-11-01T09:00:00Z",
            ],
            "spots": spots ?? validSpots(),
            "id_aliases": idAliases,
            "map": map ?? [
                "dataset_version": 7,
                "dataset_sha256": String(repeating: "a", count: 64),
                "geojson": geojson(),
            ],
        ]
    }

    // MARK: - イベント・開催回・カテゴリ（E2-5 改訂1、2.1.0）

    static let categoryID = "0199b000-0000-7000-8000-000000000001"
    static let occurrenceID = "0199b000-0000-7000-8000-000000000010"
    static let dayID = "0199b000-0000-7000-8000-000000000011"
    static let eventID = "0199b000-0000-7000-8000-000000000100"

    static func slot(
        id: String,
        dayID: String = BundleFixtures.dayID,
        date: String = "2027-08-01",
        timeMode: String = "fixed",
        start: String = "10:30",
        end: String = "11:15",
        status: String = "normal",
        cancelNote: Any = NSNull(),
        venues: [String] = ["mb_2f_cl_001"]
    ) -> [String: Any] {
        [
            "id": id,
            "day_id": dayID,
            "date": date,
            "time_mode": timeMode,
            "start": start,
            "end": end,
            "participation": timeMode == "allDay" ? "anytime" : "atStart",
            "status": status,
            "cancel_note": cancelNote,
            "venues": venues.map { ["spot_id": $0, "note": NSNull()] },
        ]
    }

    static func event(
        id: String = BundleFixtures.eventID,
        title: String = "模擬授業",
        description: Any = NSNull(),
        categoryID: Any = BundleFixtures.categoryID,
        occurrenceID: String = BundleFixtures.occurrenceID,
        slots: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": id,
            "title": title,
            "description": description,
            "category_id": categoryID,
            "occurrence_id": occurrenceID,
            "slots": slots,
        ]
    }

    /// 2.1.0 の bundle。開催日（10:00–15:00）に、時間指定の枠と終日の枠を持つイベントが1件。
    static func eventBundleObject(
        events: [[String: Any]]? = nil,
        categories: [[String: Any]]? = nil,
        days: [[String: Any]]? = nil
    ) -> [String: Any] {
        var object = bundleObject(schemaVersion: "2.1.0")
        object["categories"] = categories ?? [["id": categoryID, "name": "体験授業"]]
        object["occurrences"] = [[
            "id": occurrenceID,
            "name": "8月オープンキャンパス",
            "days": days ?? [[
                "id": dayID, "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00",
                "status": "normal", "cancel_note": NSNull(),
            ]],
        ]]
        object["events"] = events ?? [event(slots: [
            slot(id: "0199b000-0000-7000-8000-000000000101"),
            slot(id: "0199b000-0000-7000-8000-000000000102", timeMode: "allDay", start: "10:00", end: "15:00", venues: ["mb"]),
        ])]
        return object
    }

    static func data(_ object: [String: Any]) -> Data {
        // 決定的なバイト列にする（同じ入力から同じ SHA-256）。
        // swiftlint:disable:next force_try
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// 本体と、本体どおりのヘッダーの組。
    static func response(
        _ object: [String: Any],
        etag: String? = "\"sha256-fixture-gzip\""
    ) -> (body: Data, headers: ParticipantBundleHeaders) {
        let body = data(object)
        let meta = object["nexus_bundle"] as? [String: Any]
        let headers = ParticipantBundleHeaders(
            sha256: ParticipantBundleValidator.sha256Hex(of: body),
            byteLength: body.count,
            bundleVersion: (meta?["bundle_version"] as? Int64) ?? 0,
            schemaVersion: (meta?["schema_version"] as? String) ?? "",
            etag: etag
        )
        return (body, headers)
    }
}
