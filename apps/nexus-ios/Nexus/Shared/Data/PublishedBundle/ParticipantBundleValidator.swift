import CryptoKit
import Foundation

/// 配信応答のヘッダーのうち、bundle の照合に使うもの（E2-5 §4.1・§4.1.1）。
///
/// ETag は条件付き GET の鍵であり、照合には使わない（§6 規則9）。
struct ParticipantBundleHeaders: Equatable, Sendable {
    let sha256: String
    let byteLength: Int
    let bundleVersion: Int64
    let schemaVersion: String
    let etag: String?
}

enum ParticipantBundleError: Error, Equatable {
    /// 非圧縮の大きさが硬い上限（10 MiB）を超えた（§3.4、§6 規則8）。
    case exceedsHardLimit(byteLength: Int)
    case lengthMismatch(expected: Int, actual: Int)
    case checksumMismatch
    case undecodable
    case versionMismatch(header: Int64, payload: Int64)
    /// 対応していないメジャー版。保存済みの版を使い続ける（§6 規則6）。
    case unsupportedSchema(String)
    /// 保存済みより小さい版。古いキャッシュ・中継の応答として採用しない（§6 規則4）。
    case olderThanStored(received: Int64, stored: Int64)
    /// 同じ版番号で中身が違う。配信側の不変条件（§5.3-6）に反する。
    case conflictingContentForVersion(Int64)
    case invariantViolated(ParticipantBundleInvariant)
}

/// §5.3 の不変条件のうち、端末で検査できるもの。
enum ParticipantBundleInvariant: Equatable, Sendable {
    case duplicateSpotID(String)
    case duplicateAlias(String)
    case aliasCollidesWithID(String)
    case aliasTargetMissing(alias: String, canonicalID: String)
    case placementWithoutMap(spotID: String)
    case destinationFeatureMissing(spotID: String)
    case placementMismatch(spotID: String)
    case unresolvedReference(spotID: String, id: String)
    case floorBuildingMismatch(spotID: String)
    case placementMissing(spotID: String)
    /// 目的地種別ごとの null の制約（E2-5 §5.2、E1-4 改訂1 §4.3）に合わない。
    case placementShapeInvalid(spotID: String)
    /// `access_node_id` の参照先がノードでない、または所属が合わない（E1-4 改訂1 §4.1・§4.2・§4.4）。
    case accessNodeInvalid(spotID: String)
}

/// 受信した bundle を、保存する前に検証する（§6 規則2・6・8）。
enum ParticipantBundleValidator {
    /// 非圧縮の UTF-8 バイト数の硬い上限（§3.4）。
    static let hardLimitBytes = 10 * 1024 * 1024
    /// 対応する bundle 契約と GeoJSON 契約のメジャー版。
    static let supportedMajorVersion = 2
    /// spot の解決元になれる `feature_type`（§5.4、E1-4 改訂1 §4.3）。
    static let destinationFeatureTypes: Set<String> = ["building", "formal_entrance", "room", "landmark"]

    static func validate(body: Data, headers: ParticipantBundleHeaders) throws -> ParticipantBundle {
        guard body.count <= hardLimitBytes, headers.byteLength <= hardLimitBytes else {
            throw ParticipantBundleError.exceedsHardLimit(byteLength: max(body.count, headers.byteLength))
        }
        guard body.count == headers.byteLength else {
            throw ParticipantBundleError.lengthMismatch(expected: headers.byteLength, actual: body.count)
        }
        guard sha256Hex(of: body) == headers.sha256 else {
            throw ParticipantBundleError.checksumMismatch
        }
        try requireSupportedMajor(headers.schemaVersion)

        let bundle: ParticipantBundle
        do {
            bundle = try JSONDecoder().decode(ParticipantBundle.self, from: body)
        } catch {
            throw ParticipantBundleError.undecodable
        }

        guard bundle.meta.bundleVersion == headers.bundleVersion else {
            throw ParticipantBundleError.versionMismatch(
                header: headers.bundleVersion,
                payload: bundle.meta.bundleVersion
            )
        }
        try requireSupportedMajor(bundle.meta.schemaVersion)
        if let map = bundle.map {
            try requireSupportedMajor(map.geojson.schemaVersion)
        }
        try checkInvariants(bundle)
        return bundle
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func requireSupportedMajor(_ version: String) throws {
        guard semanticMajorVersion(of: version) == supportedMajorVersion else {
            throw ParticipantBundleError.unsupportedSchema(version)
        }
    }

    /// SemVer 2.0.0 の `MAJOR.MINOR.PATCH`（任意の pre-release・build を含む）を解析し、MAJOR を返す。
    /// 形式に合わなければ nil（`2`、`.2`、`02.0.0`、`2..0` などは対応版として扱わない）。
    static func semanticMajorVersion(of version: String) -> Int? {
        var core = Substring(version)
        if let plus = core.firstIndex(of: "+") {
            let build = core[core.index(after: plus)...]
            guard isValidDotSeparatedIdentifiers(build) else { return nil }
            core = core[..<plus]
        }
        if let dash = core.firstIndex(of: "-") {
            let preRelease = core[core.index(after: dash)...]
            guard isValidDotSeparatedIdentifiers(preRelease) else { return nil }
            core = core[..<dash]
        }

        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  part == "0" || part.first != "0",
                  let number = Int(part)
            else {
                return nil
            }
            numbers.append(number)
        }
        return numbers[0]
    }

    private static func isValidDotSeparatedIdentifiers(_ text: Substring) -> Bool {
        let identifiers = text.split(separator: ".", omittingEmptySubsequences: false)
        return !identifiers.isEmpty && identifiers.allSatisfy { identifier in
            !identifier.isEmpty && identifier.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    /// 目的地種別ごとの null の制約（E2-5 §5.2、E1-4 改訂1 §4.1〜§4.4）。
    private static func placementShapeIsValid(_ placement: ParticipantBundle.Placement, spotID: String) -> Bool {
        switch placement.featureType {
        case "building":
            // 建物は自分自身の ID を所属とし、階も点も持たない（Polygon の重心を推測しない）。
            return placement.buildingID == spotID && placement.floorID == nil && placement.point == nil
        case "formal_entrance":
            // 到達ノードは入口の接続ノードから端末が求めるため、placement には入れない。
            return placement.buildingID != nil && placement.floorID != nil
                && isPosition(placement.point) && placement.accessNodeID == nil
        case "room":
            return placement.buildingID != nil && placement.floorID != nil && isPosition(placement.point)
        case "landmark":
            return placement.buildingID == nil && placement.floorID == nil && isPosition(placement.point)
        default:
            return false
        }
    }

    /// `[longitude, latitude]` の2要素で、範囲内の有限値か（E1-4・E1-5）。
    private static func isPosition(_ point: [Double]?) -> Bool {
        guard let point, point.count == 2, point.allSatisfy(\.isFinite) else { return false }
        return (-180...180).contains(point[0]) && (-90...90).contains(point[1])
    }

    /// §5.3 の不変条件1〜3。比較はすべて大文字小文字を区別する完全一致（E1-3）。
    static func checkInvariants(_ bundle: ParticipantBundle) throws {
        func fail(_ invariant: ParticipantBundleInvariant) -> ParticipantBundleError {
            .invariantViolated(invariant)
        }

        // 1. spots[].id は一意。
        var spotIDs = Set<String>()
        for spot in bundle.spots where !spotIDs.insert(spot.id).inserted {
            throw fail(.duplicateSpotID(spot.id))
        }

        let features = bundle.map?.geojson.features ?? []
        let floors = bundle.map?.geojson.floors ?? []
        let featureIDs = Set(features.map(\.id))
        let floorIDs = Set(floors.map(\.id))

        // 2. alias は一意で、spot・Feature・floor の ID と衝突せず、解決先は spots に存在する。
        var aliases = Set<String>()
        for alias in bundle.idAliases {
            guard aliases.insert(alias.alias).inserted else {
                throw fail(.duplicateAlias(alias.alias))
            }
            if spotIDs.contains(alias.alias) || featureIDs.contains(alias.alias) || floorIDs.contains(alias.alias) {
                throw fail(.aliasCollidesWithID(alias.alias))
            }
            guard spotIDs.contains(alias.canonicalID) else {
                throw fail(.aliasTargetMissing(alias: alias.alias, canonicalID: alias.canonicalID))
            }
        }

        // 3. placement と目的地Featureの一致。
        let destinations = Dictionary(
            features.filter { destinationFeatureTypes.contains($0.featureType) }.map { ($0.id, [$0]) },
            uniquingKeysWith: +
        )
        let buildingIDs = Set(features.filter { $0.featureType == "building" }.map(\.id))
        let featuresByID = Dictionary(features.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let floorBuilding = Dictionary(floors.map { ($0.id, $0.buildingID) }, uniquingKeysWith: { first, _ in first })

        for spot in bundle.spots {
            let candidates = destinations[spot.id] ?? []
            guard let placement = spot.placement else {
                // 解決できるのに null にしない。
                if !candidates.isEmpty {
                    throw fail(.placementMissing(spotID: spot.id))
                }
                continue
            }
            guard bundle.map != nil else {
                throw fail(.placementWithoutMap(spotID: spot.id))
            }
            guard candidates.count == 1, let feature = candidates.first else {
                throw fail(.destinationFeatureMissing(spotID: spot.id))
            }

            let expectedBuildingID = feature.featureType == "building" ? feature.id : feature.buildingID
            guard placement.featureType == feature.featureType,
                  placement.buildingID == expectedBuildingID,
                  placement.floorID == feature.floorID,
                  placement.point == feature.point,
                  placement.accessNodeID == feature.accessNodeID
            else {
                throw fail(.placementMismatch(spotID: spot.id))
            }
            guard placementShapeIsValid(placement, spotID: spot.id) else {
                throw fail(.placementShapeInvalid(spotID: spot.id))
            }

            if let buildingID = placement.buildingID, !buildingIDs.contains(buildingID) {
                throw fail(.unresolvedReference(spotID: spot.id, id: buildingID))
            }
            if let floorID = placement.floorID {
                guard let owner = floorBuilding[floorID] else {
                    throw fail(.unresolvedReference(spotID: spot.id, id: floorID))
                }
                guard owner == placement.buildingID else {
                    throw fail(.floorBuildingMismatch(spotID: spot.id))
                }
            }
            if let accessNodeID = placement.accessNodeID {
                guard let node = featuresByID[accessNodeID] else {
                    throw fail(.unresolvedReference(spotID: spot.id, id: accessNodeID))
                }
                // room は同じ階の屋内ノード、building は同じ建物の屋内ノード、landmark は屋外ノード。
                let nodeIsValid: Bool
                switch placement.featureType {
                case "room":
                    nodeIsValid = node.featureType == "indoor_node" && node.floorID == placement.floorID
                case "building":
                    nodeIsValid = node.featureType == "indoor_node" && node.buildingID == placement.buildingID
                case "landmark":
                    nodeIsValid = node.featureType == "outdoor_node"
                default:
                    nodeIsValid = false
                }
                guard nodeIsValid else {
                    throw fail(.accessNodeInvalid(spotID: spot.id))
                }
            }
        }
    }
}
