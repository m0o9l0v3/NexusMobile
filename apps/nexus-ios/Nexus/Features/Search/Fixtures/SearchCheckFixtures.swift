#if DEBUG
import Foundation

/// 原点付近の合成座標に置いた画面検証用データ。建物の位置・形・部屋の配置は実測値を表さない。
enum SearchCheckFixtures: String {
    case normal, saved, empty, notPublished, failed

    static let provisionalNotice = "検証用の仮検索データ（正式データではありません）"

    static func scenario(arguments: [String]) -> Self? {
        guard let index = arguments.firstIndex(of: "-NexusSearchCheck") else { return nil }
        return arguments.dropFirst(index + 1).first.flatMap(Self.init(rawValue:)) ?? .normal
    }

    var source: PublishedBundleSource {
        switch self {
        case .notPublished: return .fixed(nil, absence: .notPublished)
        case .failed: return .fixed(nil, absence: .checkFailed)
        case .normal, .saved, .empty: return .fixed(snapshot)
        }
    }

    var snapshot: PublishedBundleSnapshot? {
        guard self != .notPublished, self != .failed else { return nil }
        let stored = self == .empty ? Self.emptyBundle : Self.fullBundle
        return .init(stored: stored, isConfirmedLatest: self != .saved, lastConfirmedAt: nil)
    }

    private static let emptyBundle = validated(contents: """
        "spots": [], "id_aliases": [], "map": null
        """)
    private static let fullBundle = validated(contents: contents)

    private static func validated(contents: String) -> StoredParticipantBundle {
        let body = Data("""
        {
          "nexus_bundle": {"schema_version":"2.1.0","bundle_version":27,"release_id":"0192f0a1-0000-7000-8000-000000000027","published_at":"2026-11-01T09:00:00Z"},
          \(contents),
          "categories": [], "occurrences": [], "events": []
        }
        """.utf8)
        let headers = ParticipantBundleHeaders(sha256: ParticipantBundleValidator.sha256Hex(of: body),
            byteLength: body.count, bundleVersion: 27, schemaVersion: "2.1.0", etag: nil)
        // 定数の不整合を DEBUG 起動と単体テストで検出する。
        let bundle = try! ParticipantBundleValidator.validate(body: body, headers: headers)
        let metadata = StoredBundleMetadata(bundleVersion: bundle.meta.bundleVersion, releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion, sha256: headers.sha256, byteLength: body.count,
            publishedAt: bundle.meta.publishedAt, etag: nil, storedAt: Date(timeIntervalSince1970: 0))
        return .init(bundle: bundle, metadata: metadata)
    }

    private static let contents = """
    "spots": [
      {"id":"mb","name":"教室棟","kind":"facility","description":null,"search_aliases":["きょうしつとう","ほんかん","Main Building"],"utilization":"available","placement":{"feature_type":"building","building_id":"mb","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"hgr_a","name":"格納庫A","kind":"facility","description":null,"search_aliases":["かくのうこえー","ﾊﾝｶﾞｰA","Hangar A"],"utilization":"available","placement":{"feature_type":"building","building_id":"hgr_a","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"dvh","name":"Da Vinci Hall","kind":"facility","description":null,"search_aliases":["だゔぃんちほーる","ダヴィンチ","DVH"],"utilization":"available","placement":{"feature_type":"building","building_id":"dvh","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"ctc2","name":"CTC2","kind":"facility","description":null,"search_aliases":["しーてぃーしーつー","ｼｰﾃｨｰｼｰ2"],"utilization":"available","placement":{"feature_type":"building","building_id":"ctc2","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"mb_2f_cl_001","name":"2A教室","kind":"classroom","description":null,"search_aliases":["にーえー","Room 2A","2A"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_2f","point":[0.0002,0.0008],"access_node_id":null}},
      {"id":"ptb","name":"実習棟","kind":"facility","description":null,"search_aliases":["じっしゅうとう"],"utilization":"available","placement":{"feature_type":"building","building_id":"ptb","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"mb_ent_001","name":"教室棟 正面入口","kind":"facility","description":null,"search_aliases":["しょうめんいりぐち"],"utilization":"available","placement":{"feature_type":"formal_entrance","building_id":"mb","floor_id":"mb_1f","point":[0.0004,0],"access_node_id":null}},
      {"id":"campus_lm_001","name":"案内看板（検証用）","kind":"facility","description":null,"search_aliases":["かんばん"],"utilization":"available","placement":{"feature_type":"landmark","building_id":null,"floor_id":null,"point":[0.0013,0.0015],"access_node_id":null}},
      {"id":"mb_1f_rm_001","name":"多目的室","kind":"facility","description":null,"search_aliases":["たもくてきしつ"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","point":[0.0002,0.0003],"access_node_id":null}},
      {"id":"mb_2f_rm_001","name":"多目的室","kind":"facility","description":null,"search_aliases":["たもくてきしつ"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_2f","point":[0.0006,0.0009],"access_node_id":null}},
      {"id":"ctc2_1f_rm_001","name":"受付","kind":"service","description":null,"search_aliases":["うけつけ"],"utilization":"available","placement":{"feature_type":"room","building_id":"ctc2","floor_id":"ctc2_1f","point":[0.0004,0.0026],"access_node_id":null}},
      {"id":"mb_1f_rm_002","name":"受付","kind":"service","description":null,"search_aliases":["うけつけ"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","point":[0.0004,0.0003],"access_node_id":null}},
      {"id":"mb_1f_cl_002","name":"実習室","kind":"classroom","description":null,"search_aliases":["じっしゅうしつ"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","point":[0.0004,0.0006],"access_node_id":null}},
      {"id":"mb_1f_rm_003","name":"実習室","kind":"facility","description":null,"search_aliases":["じっしゅうしつ"],"utilization":"available","placement":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","point":[0.0006,0.0006],"access_node_id":null}},
      {"id":"sab","name":"技能審査棟","kind":null,"description":null,"search_aliases":["ぎのうしんさとう"],"utilization":"available","placement":{"feature_type":"building","building_id":"sab","floor_id":null,"point":null,"access_node_id":null}},
      {"id":"campus_unplaced_001","name":"仮設案内所（地図未掲載・検証用）","kind":"service","description":null,"search_aliases":["かせつあんないじょ","unplaced"],"utilization":"available","placement":null}
    ],
    "id_aliases": [{"alias":"mb_f2_cr_2a","canonical_id":"mb_2f_cl_001"}],
    "map": {
      "dataset_version":1, "dataset_sha256":"43851ed43c3378e75fecd19f5ee6a148c6104a077a5821cd6767ad1c1dbc60f9",
      "geojson": {
        "type":"FeatureCollection",
        "nexus":{"schema_version":"2.0.0","floors":[{"id":"mb_1f","building_id":"mb","name":"1F"},{"id":"mb_2f","building_id":"mb","name":"2F"},{"id":"ctc2_1f","building_id":"ctc2","name":"1F"}]},
        "features":[
          {"type":"Feature","id":"mb","geometry":{"type":"Polygon","coordinates":[[[0,0],[0.00085,0],[0.00085,0.0012],[0,0.0012],[0,0]]]},"properties":{"feature_type":"building","name":"教室棟"}},
          {"type":"Feature","id":"hgr_a","geometry":{"type":"Polygon","coordinates":[[[0.002,0],[0.00285,0],[0.00285,0.0012],[0.002,0.0012],[0.002,0]]]},"properties":{"feature_type":"building","name":"格納庫A"}},
          {"type":"Feature","id":"dvh","geometry":{"type":"Polygon","coordinates":[[[0.004,0],[0.00485,0],[0.00485,0.0012],[0.004,0.0012],[0.004,0]]]},"properties":{"feature_type":"building","name":"Da Vinci Hall"}},
          {"type":"Feature","id":"ctc2","geometry":{"type":"Polygon","coordinates":[[[0,0.002],[0.00085,0.002],[0.00085,0.0032],[0,0.0032],[0,0.002]]]},"properties":{"feature_type":"building","name":"CTC2"}},
          {"type":"Feature","id":"mb_2f_cl_001","geometry":{"type":"Point","coordinates":[0.0002,0.0008]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_2f","room_type":"cl"}},
          {"type":"Feature","id":"ptb","geometry":{"type":"Polygon","coordinates":[[[0.002,0.002],[0.00285,0.002],[0.00285,0.0032],[0.002,0.0032],[0.002,0.002]]]},"properties":{"feature_type":"building","name":"実習棟"}},
          {"type":"Feature","id":"mb_ent_001","geometry":{"type":"Point","coordinates":[0.0004,0]},"properties":{"feature_type":"formal_entrance","name":"教室棟 正面入口","building_id":"mb","floor_id":"mb_1f","outside_node_id":"campus_n_001","inside_node_id":"mb_1f_n_001","is_primary":true,"accessibility":"unknown"}},
          {"type":"Feature","id":"campus_lm_001","geometry":{"type":"Point","coordinates":[0.0013,0.0015]},"properties":{"feature_type":"landmark","scope":"campus"}},
          {"type":"Feature","id":"mb_1f_rm_001","geometry":{"type":"Point","coordinates":[0.0002,0.0003]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","room_type":"rm"}},
          {"type":"Feature","id":"mb_2f_rm_001","geometry":{"type":"Point","coordinates":[0.0006,0.0009]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_2f","room_type":"rm"}},
          {"type":"Feature","id":"ctc2_1f_rm_001","geometry":{"type":"Point","coordinates":[0.0004,0.0026]},"properties":{"feature_type":"room","building_id":"ctc2","floor_id":"ctc2_1f","room_type":"rm"}},
          {"type":"Feature","id":"mb_1f_rm_002","geometry":{"type":"Point","coordinates":[0.0004,0.0003]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","room_type":"rm"}},
          {"type":"Feature","id":"mb_1f_cl_002","geometry":{"type":"Point","coordinates":[0.0004,0.0006]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","room_type":"cl"}},
          {"type":"Feature","id":"mb_1f_rm_003","geometry":{"type":"Point","coordinates":[0.0006,0.0006]},"properties":{"feature_type":"room","building_id":"mb","floor_id":"mb_1f","room_type":"rm"}},
          {"type":"Feature","id":"sab","geometry":{"type":"Polygon","coordinates":[[[0.004,0.002],[0.00485,0.002],[0.00485,0.0032],[0.004,0.0032],[0.004,0.002]]]},"properties":{"feature_type":"building","name":"技能審査棟"}},
          {"type":"Feature","id":"campus_n_001","geometry":{"type":"Point","coordinates":[0.0004,-0.0001]},"properties":{"feature_type":"outdoor_node","scope":"campus","node_kind":"entrance_approach"}},
          {"type":"Feature","id":"mb_1f_n_001","geometry":{"type":"Point","coordinates":[0.0004,0.0001]},"properties":{"feature_type":"indoor_node","building_id":"mb","floor_id":"mb_1f","node_kind":"junction"}}
        ]
      }
    }
    """
}
#endif
