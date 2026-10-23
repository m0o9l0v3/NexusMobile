import Foundation

/// 1つの bundle の版から、画面に渡す地点の要約を作る。
///
/// bundle 内の ID はすでに canonical ID なので、ここでは解決器を通さず完全一致で引く（E2-5 §6 規則11）。
/// 地点詳細（`SpotDetailPresentation`）は `MapContentClient` だけが作る。
struct BundleSpotCatalog: Sendable {
    let snapshot: PublishedBundleSnapshot
    private let spotsByID: [String: ParticipantBundle.Spot]
    private let buildingNames: [String: String]
    private let floorNames: [String: String]

    init(snapshot: PublishedBundleSnapshot) {
        self.snapshot = snapshot
        // 不変条件（§5.3）で spots[].id の一意性は検査済み。
        spotsByID = Dictionary(snapshot.bundle.spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let geojson = snapshot.bundle.map?.geojson
        var buildings: [String: String] = [:]
        for feature in geojson?.features ?? [] where feature.featureType == "building" {
            if let name = feature.name {
                buildings[feature.id] = name
            }
        }
        buildingNames = buildings
        var floors: [String: String] = [:]
        for floor in geojson?.floors ?? [] {
            if let name = floor.name {
                floors[floor.id] = name
            }
        }
        floorNames = floors
    }

    /// bundle の順（Studio の射影の順）のままの全地点。
    var allSpots: [ParticipantBundle.Spot] { snapshot.bundle.spots }

    func spot(for canonicalSpotID: CanonicalSpotID) -> ParticipantBundle.Spot? {
        spotsByID[canonicalSpotID.rawValue]
    }

    func summary(for spot: ParticipantBundle.Spot) -> SpotSummary {
        SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: spot.id),
            displayName: spot.name,
            // null・未知の値は種別なし。既存の種別に丸めない（E2-5 O-2c）。
            kind: spot.kind.flatMap(SpotKind.init(rawValue:)),
            buildingName: buildingName(for: spot),
            floorName: spot.placement?.floorID.flatMap { floorNames[$0] }
        )
    }

    /// 所在する建物の名前（E2-5 §5.2）。`building.properties.name` は「ほかの地点の所在する建物」の
    /// 名前に使うため、建物自身を目的地にした spot には付けない。
    private func buildingName(for spot: ParticipantBundle.Spot) -> String? {
        guard let placement = spot.placement, placement.featureType != "building",
              let buildingID = placement.buildingID
        else {
            return nil
        }
        return buildingNames[buildingID]
    }

    /// 保存版として表示するときの説明（E2-5 §6 規則7）。最新だと確認できていれば nil。
    var savedMetadata: NexusSavedMetadata? {
        guard !snapshot.isConfirmedLatest else { return nil }
        let metadata = snapshot.stored.metadata
        let publishedAt = Self.parseRFC3339(metadata.publishedAt)
        var details = ["版 \(metadata.bundleVersion)"]
        if let publishedAt {
            details.append("\(Self.displayText(for: publishedAt)) 公開")
        }
        if let lastConfirmedAt = snapshot.lastConfirmedAt {
            details.append("最終確認 \(Self.displayText(for: lastConfirmedAt))")
        } else {
            details.append("最新情報は確認できていません")
        }
        return NexusSavedMetadata(
            title: "保存版を表示しています",
            detail: details.joined(separator: "・"),
            bundleVersion: metadata.bundleVersion,
            publishedAt: publishedAt,
            lastConfirmedAt: snapshot.lastConfirmedAt
        )
    }

    /// 画面の表示は日本時間に固定する（日時は UTC で保存し、表示は Asia/Tokyo）。
    static func displayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    /// `published_at`（RFC 3339 の UTC）。読めない値は nil にし、推測で埋めない。
    static func parseRFC3339(_ text: String) -> Date? {
        let normalized = text.uppercased()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: normalized) ?? plain.date(from: normalized)
    }
}
