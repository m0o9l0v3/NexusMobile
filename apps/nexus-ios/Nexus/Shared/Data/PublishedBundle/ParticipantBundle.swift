import Foundation

/// 参加者向け公開データ配信契約 v2 の bundle（`docs/decisions/E2-5-participant-data-delivery-v2.md` §5）。
///
/// 地点と地図を1つの版として持つ。ID は配信された文字列のまま保持し、
/// 大文字小文字の正規化や別地点への置換をしない（E1-3）。
/// 未知の項目はデコード時に無視する（同じメジャー版の中でのマイナー版の追加、§6 規則6）。
struct ParticipantBundle: Decodable, Equatable, Sendable {
    let meta: Meta
    let spots: [Spot]
    let idAliases: [IDAlias]
    let map: MapPayload?

    enum CodingKeys: String, CodingKey {
        case meta = "nexus_bundle"
        case spots
        case idAliases = "id_aliases"
        case map
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decode(Meta.self, forKey: .meta)
        spots = try container.decode([Spot].self, forKey: .spots)
        idAliases = try container.decode([IDAlias].self, forKey: .idAliases)
        map = try container.decodeRequiredNullable(MapPayload.self, forKey: .map)
    }

    struct Meta: Decodable, Equatable, Sendable {
        let schemaVersion: String
        let bundleVersion: Int64
        let releaseID: String
        let publishedAt: String

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case bundleVersion = "bundle_version"
            case releaseID = "release_id"
            case publishedAt = "published_at"
        }
    }

    struct Spot: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        /// null と未知の値はどちらも「種別なし」として扱う（O-2c）。値の解釈は利用側で行う。
        let kind: String?
        let description: String?
        let searchAliases: [String]
        let utilization: String
        let placement: Placement?

        enum CodingKeys: String, CodingKey {
            case id, name, kind, description, utilization, placement
            case searchAliases = "search_aliases"
        }

        /// `kind`・`description`・`placement` は「必須（null可）」。キーの欠落は null と区別して拒否する（§5.2）。
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            kind = try container.decodeRequiredNullable(String.self, forKey: .kind)
            description = try container.decodeRequiredNullable(String.self, forKey: .description)
            searchAliases = try container.decode([String].self, forKey: .searchAliases)
            utilization = try container.decode(String.self, forKey: .utilization)
            placement = try container.decodeRequiredNullable(Placement.self, forKey: .placement)
        }
    }

    /// 目的地Featureから Studio が解決した位置（E2-5 §5.2・§5.4）。正本は `map.geojson`。
    struct Placement: Decodable, Equatable, Sendable {
        let featureType: String
        let buildingID: String?
        let floorID: String?
        let point: [Double]?
        let accessNodeID: String?

        enum CodingKeys: String, CodingKey {
            case featureType = "feature_type"
            case buildingID = "building_id"
            case floorID = "floor_id"
            case point
            case accessNodeID = "access_node_id"
        }

        /// 各項目は「必須（null可）」。キーの欠落は null と区別して拒否する（§5.2）。
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            featureType = try container.decode(String.self, forKey: .featureType)
            buildingID = try container.decodeRequiredNullable(String.self, forKey: .buildingID)
            floorID = try container.decodeRequiredNullable(String.self, forKey: .floorID)
            point = try container.decodeRequiredNullable([Double].self, forKey: .point)
            accessNodeID = try container.decodeRequiredNullable(String.self, forKey: .accessNodeID)
        }
    }

    struct IDAlias: Decodable, Equatable, Sendable {
        let alias: String
        let canonicalID: String

        enum CodingKeys: String, CodingKey {
            case alias
            case canonicalID = "canonical_id"
        }
    }

    struct MapPayload: Decodable, Equatable, Sendable {
        let datasetVersion: Int64
        let datasetSHA256: String
        let geojson: MapGeoJSON

        enum CodingKeys: String, CodingKey {
            case datasetVersion = "dataset_version"
            case datasetSHA256 = "dataset_sha256"
            case geojson
        }
    }
}

/// `map.geojson`（E1-4 改訂1、payload 契約 2.x）のうち、bundle の不変条件の検査に必要な範囲。
///
/// 描画や経路探索に必要な項目（辺の距離など）は、それぞれの実装で追加する。
struct MapGeoJSON: Decodable, Equatable, Sendable {
    let schemaVersion: String
    let floors: [Floor]
    let features: [Feature]

    enum CodingKeys: String, CodingKey {
        case nexus, features
    }

    private enum NexusKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case floors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nexus = try container.nestedContainer(keyedBy: NexusKeys.self, forKey: .nexus)
        schemaVersion = try nexus.decode(String.self, forKey: .schemaVersion)
        floors = try nexus.decode([Floor].self, forKey: .floors)
        features = try container.decode([Feature].self, forKey: .features)
    }

    init(schemaVersion: String, floors: [Floor], features: [Feature]) {
        self.schemaVersion = schemaVersion
        self.floors = floors
        self.features = features
    }

    struct Floor: Decodable, Equatable, Sendable {
        let id: String
        let buildingID: String
        /// 階の表示名（例「2F」）。任意の項目。
        let name: String?

        enum CodingKeys: String, CodingKey {
            case id, name
            case buildingID = "building_id"
        }

        init(id: String, buildingID: String, name: String? = nil) {
            self.id = id
            self.buildingID = buildingID
            self.name = name
        }
    }

    struct Feature: Decodable, Equatable, Sendable {
        let id: String
        let featureType: String
        let buildingID: String?
        let floorID: String?
        let accessNodeID: String?
        /// ノードの種別（`junction` / `destination` / `transition` / `entrance_approach`）。ノード以外は nil。
        let nodeKind: String?
        /// `building` などの表示名。`room` / `landmark` は持たない（E1-4 改訂1 §6）。
        let name: String?
        let geometry: Geometry

        /// Point のときだけ座標を返す。Polygon などは nil（重心などを推測しない）。
        var point: [Double]? {
            if case .point(let position) = geometry { return position }
            return nil
        }

        /// E1-4 が許す geometry。座標の構造はデコード時に確かめ、値の妥当性は validator が確かめる。
        enum Geometry: Equatable, Sendable {
            case point([Double])
            case lineString([[Double]])
            case polygon([[[Double]]])
        }

        enum CodingKeys: String, CodingKey {
            case id, geometry, properties
        }

        private enum GeometryKeys: String, CodingKey {
            case type, coordinates
        }

        private enum PropertyKeys: String, CodingKey {
            case featureType = "feature_type"
            case buildingID = "building_id"
            case floorID = "floor_id"
            case accessNodeID = "access_node_id"
            case nodeKind = "node_kind"
            case name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)

            let properties = try container.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
            featureType = try properties.decode(String.self, forKey: .featureType)
            buildingID = try properties.decodeIfPresent(String.self, forKey: .buildingID)
            floorID = try properties.decodeIfPresent(String.self, forKey: .floorID)
            accessNodeID = try properties.decodeIfPresent(String.self, forKey: .accessNodeID)
            nodeKind = try properties.decodeIfPresent(String.self, forKey: .nodeKind)
            name = try properties.decodeIfPresent(String.self, forKey: .name)

            let geometryContainer = try container.nestedContainer(keyedBy: GeometryKeys.self, forKey: .geometry)
            let type = try geometryContainer.decode(String.self, forKey: .type)
            switch type {
            case "Point":
                geometry = .point(try geometryContainer.decode([Double].self, forKey: .coordinates))
            case "LineString":
                geometry = .lineString(try geometryContainer.decode([[Double]].self, forKey: .coordinates))
            case "Polygon":
                geometry = .polygon(try geometryContainer.decode([[[Double]]].self, forKey: .coordinates))
            default:
                // E1-4 は Point・LineString・Polygon 以外を許さない。geometry 型の追加はメジャー版。
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: geometryContainer,
                    debugDescription: "未対応の geometry 型: \(type)"
                )
            }
        }

        init(
            id: String,
            featureType: String,
            buildingID: String? = nil,
            floorID: String? = nil,
            accessNodeID: String? = nil,
            nodeKind: String? = nil,
            name: String? = nil,
            geometry: Geometry
        ) {
            self.id = id
            self.featureType = featureType
            self.buildingID = buildingID
            self.floorID = floorID
            self.accessNodeID = accessNodeID
            self.nodeKind = nodeKind
            self.name = name
            self.geometry = geometry
        }
    }
}

extension KeyedDecodingContainer {
    /// 「必須（null可）」の項目を読む。null は nil、キーの欠落はエラーにする。
    ///
    /// 合成された `Decodable` は Optional のキーが欠落しても nil にしてしまうため、
    /// 生成側の不完全な payload を正常な bundle と区別できない。
    func decodeRequiredNullable<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "必須（null可）の項目が欠落している")
            )
        }
        return try decodeIfPresent(type, forKey: key)
    }
}
