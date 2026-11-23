#if DEBUG
import Foundation

/// 地点名・経路は画面確認用。端末の公開データには保存しない。
enum RouteCheckFixtures {
    static let provisionalNotice = "検証用の仮経路データ（実測データではありません）"
    static let defaultOrigin = RouteOrigin.destination(.init(rawValue: "campus_lm_001"))

    enum Scenario: String, CaseIterable {
        case found, indoor, samePoint, disconnected, unreachable, notRoutable, unknown, unavailable

        var destination: CanonicalSpotID {
            let id: String = switch self {
            case .found, .unavailable: "hgr_a"
            case .indoor: "mb_1f_cl_001"
            case .samePoint: "campus_lm_001"
            case .disconnected: "sab"
            case .unreachable: "hgr_b"
            case .notRoutable: "ptb"
            case .unknown: "unregistered"
            }
            return .init(rawValue: id)
        }
    }

    static func scenario(arguments: [String]) -> Scenario? {
        guard let index = arguments.firstIndex(of: "-NexusRouteCheck") else { return nil }
        guard let next = arguments.dropFirst(index + 1).first, !next.hasPrefix("-") else { return .found }
        return Scenario(rawValue: next)
    }

    static func routeHandler(for scenario: Scenario) -> RouteRequestHandling {
        .bundle(source: scenario == .unavailable ? .fixed(nil) : source, defaultOrigin: defaultOrigin)
    }

    static let snapshot: PublishedBundleSnapshot = {
        let data = Data(json.utf8)
        let hash = ParticipantBundleValidator.sha256Hex(of: data)
        let headers = ParticipantBundleHeaders(sha256: hash, byteLength: data.count, bundleVersion: 42,
                                              schemaVersion: "2.1.0", etag: nil)
        // 定数の不整合は DEBUG の検証起動で検出する。
        let bundle = try! ParticipantBundleValidator.validate(body: data, headers: headers)
        let metadata = StoredBundleMetadata(bundleVersion: bundle.meta.bundleVersion, releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion, sha256: hash, byteLength: data.count,
            publishedAt: bundle.meta.publishedAt, etag: nil, storedAt: Date(timeIntervalSince1970: 0))
        return .init(stored: .init(bundle: bundle, metadata: metadata), isConfirmedLatest: true, lastConfirmedAt: nil)
    }()
    static var bundle: ParticipantBundle { snapshot.bundle }
    static var source: PublishedBundleSource { .fixed(snapshot) }

    private static let json = """
    {
      "nexus_bundle": {"schema_version":"2.1.0","bundle_version":42,"release_id":"0192f0a1-0000-7000-8000-000000000042","published_at":"2026-11-01T09:00:00Z"},
      "spots": [
        {"id":"campus_lm_001","name":"正門付近（検証用）","kind":"facility","description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"landmark","building_id":null,"floor_id":null,"point":[141.68055,42.77165],"access_node_id":"campus_n_030"}},
        {"id":"hgr_a","name":"格納庫A","kind":null,"description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"building","building_id":"hgr_a","floor_id":null,"point":null,"access_node_id":null}},
        {"id":"hgr_b","name":"格納庫B","kind":null,"description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"building","building_id":"hgr_b","floor_id":null,"point":null,"access_node_id":null}},
        {"id":"mb","name":"教室棟","kind":null,"description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"building","building_id":"mb","floor_id":null,"point":null,"access_node_id":null}},
        {"id":"mb_1f_cl_001","name":"電気装備教室","kind":"classroom","description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","point":[141.6813,42.7715],"access_node_id":"mb_1f_n_005"}},
        {"id":"mb_ent_001","name":"教室棟 正面入口","kind":"facility","description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"formal_entrance","building_id":"mb","floor_id":"mb_1f","point":[141.68101,42.7714],"access_node_id":null}},
        {"id":"ptb","name":"実習棟","kind":null,"description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"building","building_id":"ptb","floor_id":null,"point":null,"access_node_id":null}},
        {"id":"sab","name":"技能審査棟","kind":null,"description":null,"search_aliases":[],"utilization":"available",
         "placement":{"feature_type":"building","building_id":"sab","floor_id":null,"point":null,"access_node_id":null}}
      ],
      "id_aliases": [],
      "map": {
        "dataset_version": 1,
        "dataset_sha256": "a90afac2dcaef9897c2759884cd01ecb2b3e3444355f5144211000dda89dcdc7",
        "geojson": {
          "type": "FeatureCollection",
          "nexus": {"schema_version":"2.0.0","floors":[
            {"id":"mb_1f","building_id":"mb","name":"1F"},
            {"id":"hgr_a_1f","building_id":"hgr_a","name":"1F"},
            {"id":"hgr_b_1f","building_id":"hgr_b","name":"1F"},
            {"id":"sab_1f","building_id":"sab","name":"1F"}
          ]},
          "features": [
            {"type":"Feature","id":"mb",
             "geometry":{"type":"Polygon","coordinates":[[[141.681,42.771],[141.682,42.771],[141.682,42.772],[141.681,42.772],[141.681,42.771]]]},
             "properties":{"feature_type":"building","name":"教室棟"}},
            {"type":"Feature","id":"campus_n_020",
             "geometry":{"type":"Point","coordinates":[141.6808,42.7714]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"junction"}},
            {"type":"Feature","id":"campus_n_021",
             "geometry":{"type":"Point","coordinates":[141.681,42.7714]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"entrance_approach"}},
            {"type":"Feature","id":"campus_e_012",
             "geometry":{"type":"LineString","coordinates":[[141.6808,42.7714],[141.681,42.7714]]},
             "properties":{"feature_type":"walking_path","scope":"campus","from_node_id":"campus_n_020","to_node_id":"campus_n_021","path_kind":"walkway","bidirectional":true,"accessibility":"accessible","distance_m":16.4,"estimated_seconds":15}},
            {"type":"Feature","id":"mb_1f_n_004",
             "geometry":{"type":"Point","coordinates":[141.68103,42.7714]},
             "properties":{"feature_type":"indoor_node","building_id":"mb","floor_id":"mb_1f","node_kind":"junction"}},
            {"type":"Feature","id":"mb_1f_n_005",
             "geometry":{"type":"Point","coordinates":[141.6812,42.7714]},
             "properties":{"feature_type":"indoor_node","building_id":"mb","floor_id":"mb_1f","node_kind":"destination"}},
            {"type":"Feature","id":"mb_1f_e_001",
             "geometry":{"type":"LineString","coordinates":[[141.68103,42.7714],[141.6812,42.7714]]},
             "properties":{"feature_type":"walking_path","scope":"indoor","building_id":"mb","floor_id":"mb_1f","from_node_id":"mb_1f_n_004","to_node_id":"mb_1f_n_005","path_kind":"corridor","bidirectional":true,"accessibility":"accessible","distance_m":13.9,"estimated_seconds":13}},
            {"type":"Feature","id":"mb_ent_001",
             "geometry":{"type":"Point","coordinates":[141.68101,42.7714]},
             "properties":{"feature_type":"formal_entrance","building_id":"mb","floor_id":"mb_1f","outside_node_id":"campus_n_021","inside_node_id":"mb_1f_n_004","is_primary":true,"accessibility":"accessible","name":"正面入口"}},
            {"type":"Feature","id":"mb_1f_cl_001",
             "geometry":{"type":"Point","coordinates":[141.6813,42.7715]},
             "properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","room_type":"cl","access_node_id":"mb_1f_n_005"}},
            {"type":"Feature","id":"campus_n_030",
             "geometry":{"type":"Point","coordinates":[141.6806,42.7716]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"destination"}},
            {"type":"Feature","id":"campus_e_013",
             "geometry":{"type":"LineString","coordinates":[[141.6808,42.7714],[141.6806,42.7716]]},
             "properties":{"feature_type":"walking_path","scope":"campus","from_node_id":"campus_n_020","to_node_id":"campus_n_030","path_kind":"walkway","bidirectional":true,"accessibility":"unknown","distance_m":27.4,"estimated_seconds":25}},
            {"type":"Feature","id":"campus_lm_001",
             "geometry":{"type":"Point","coordinates":[141.68055,42.77165]},
             "properties":{"feature_type":"landmark","scope":"campus","access_node_id":"campus_n_030"}},
            {"type":"Feature","id":"hgr_a",
             "geometry":{"type":"Polygon","coordinates":[[[141.6789,42.773],[141.6794,42.773],[141.6794,42.7734],[141.6789,42.7734],[141.6789,42.773]]]},
             "properties":{"feature_type":"building","name":"格納庫A"}},
            {"type":"Feature","id":"campus_n_031",
             "geometry":{"type":"Point","coordinates":[141.6789,42.77298]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"entrance_approach"}},
            {"type":"Feature","id":"hgr_a_1f_n_001",
             "geometry":{"type":"Point","coordinates":[141.67893,42.77302]},
             "properties":{"feature_type":"indoor_node","building_id":"hgr_a","floor_id":"hgr_a_1f","node_kind":"junction"}},
            {"type":"Feature","id":"hgr_a_ent_001",
             "geometry":{"type":"Point","coordinates":[141.6789,42.773]},
             "properties":{"feature_type":"formal_entrance","building_id":"hgr_a","floor_id":"hgr_a_1f","outside_node_id":"campus_n_031","inside_node_id":"hgr_a_1f_n_001","is_primary":true,"accessibility":"accessible"}},
            {"type":"Feature","id":"campus_e_031",
             "geometry":{"type":"LineString","coordinates":[[141.6806,42.7716],[141.68015,42.7719],[141.68015,42.77298],[141.6789,42.77298]]},
             "properties":{"feature_type":"walking_path","scope":"campus","from_node_id":"campus_n_030","to_node_id":"campus_n_031","path_kind":"walkway","bidirectional":true,"accessibility":"accessible","distance_m":228,"estimated_seconds":200}},
            {"type":"Feature","id":"hgr_b",
             "geometry":{"type":"Polygon","coordinates":[[[141.6796,42.7742],[141.6801,42.7742],[141.6801,42.7746],[141.6796,42.7746],[141.6796,42.7742]]]},
             "properties":{"feature_type":"building","name":"格納庫B"}},
            {"type":"Feature","id":"campus_n_032",
             "geometry":{"type":"Point","coordinates":[141.6796,42.77418]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"entrance_approach"}},
            {"type":"Feature","id":"hgr_b_1f_n_001",
             "geometry":{"type":"Point","coordinates":[141.67963,42.77422]},
             "properties":{"feature_type":"indoor_node","building_id":"hgr_b","floor_id":"hgr_b_1f","node_kind":"junction"}},
            {"type":"Feature","id":"hgr_b_ent_001",
             "geometry":{"type":"Point","coordinates":[141.6796,42.7742]},
             "properties":{"feature_type":"formal_entrance","building_id":"hgr_b","floor_id":"hgr_b_1f","outside_node_id":"campus_n_032","inside_node_id":"hgr_b_1f_n_001","is_primary":true,"accessibility":"accessible"}},
            {"type":"Feature","id":"campus_e_032",
             "geometry":{"type":"LineString","coordinates":[[141.6796,42.77418],[141.68015,42.77418],[141.68015,42.7719],[141.6806,42.7716]]},
             "properties":{"feature_type":"walking_path","scope":"campus","from_node_id":"campus_n_032","to_node_id":"campus_n_030","path_kind":"walkway","bidirectional":false,"accessibility":"accessible","distance_m":315,"estimated_seconds":270}},
            {"type":"Feature","id":"sab",
             "geometry":{"type":"Polygon","coordinates":[[[141.6831,42.7731],[141.6836,42.7731],[141.6836,42.7735],[141.6831,42.7735],[141.6831,42.7731]]]},
             "properties":{"feature_type":"building","name":"技能審査棟"}},
            {"type":"Feature","id":"campus_n_033",
             "geometry":{"type":"Point","coordinates":[141.6831,42.77308]},
             "properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"entrance_approach"}},
            {"type":"Feature","id":"sab_1f_n_001",
             "geometry":{"type":"Point","coordinates":[141.68313,42.77312]},
             "properties":{"feature_type":"indoor_node","building_id":"sab","floor_id":"sab_1f","node_kind":"junction"}},
            {"type":"Feature","id":"sab_ent_001",
             "geometry":{"type":"Point","coordinates":[141.6831,42.7731]},
             "properties":{"feature_type":"formal_entrance","building_id":"sab","floor_id":"sab_1f","outside_node_id":"campus_n_033","inside_node_id":"sab_1f_n_001","is_primary":true,"accessibility":"accessible"}},
            {"type":"Feature","id":"ptb",
             "geometry":{"type":"Polygon","coordinates":[[[141.6832,42.7718],[141.6837,42.7718],[141.6837,42.7722],[141.6832,42.7722],[141.6832,42.7718]]]},
             "properties":{"feature_type":"building","name":"実習棟"}}
          ]
        }
      },
      "categories": [],
      "occurrences": [],
      "events": []
    }
    """
}
#endif
