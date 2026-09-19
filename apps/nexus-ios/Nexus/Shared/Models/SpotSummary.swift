import Foundation

/// 地点の種別。Figma `2622:818` のカテゴリチップと検索結果行の「種別」に対応する。
enum SpotKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case classroom
    case facility
    case service
    case exhibit

    var displayName: String {
        switch self {
        case .classroom:
            return "教室"
        case .facility:
            return "施設"
        case .service:
            return "サービス"
        case .exhibit:
            return "展示"
        }
    }
}

/// 検索結果行と地点詳細ヘッダで共有する地点の要約。
///
/// `buildingName` / `floorName` が省略可能なのは意図的で、実測資料側に
/// 階が未記載の行・所属が未確定の行が残っているため（`nexus-map-data-review.md`）。
/// 未提供のときは推測せず「未提供」と表示する。canonical ID から `_` 区切りで
/// 建物・階を導出することも行わない（`ctc_main` / `hgr_a` のように ID 自体が
/// アンダースコアを含むため）。
struct SpotSummary: Identifiable, Equatable, Sendable {
    let canonicalSpotID: CanonicalSpotID
    let displayName: String
    let kind: SpotKind
    let buildingName: String?
    let floorName: String?

    var id: CanonicalSpotID { canonicalSpotID }

    init(
        canonicalSpotID: CanonicalSpotID,
        displayName: String,
        kind: SpotKind,
        buildingName: String? = nil,
        floorName: String? = nil
    ) {
        self.canonicalSpotID = canonicalSpotID
        self.displayName = displayName
        self.kind = kind
        self.buildingName = buildingName
        self.floorName = floorName
    }

    /// 「教室棟・2F」のような副次表示。未提供の要素は落とす。
    var locationText: String {
        [buildingName, floorName]
            .compactMap { $0 }
            .joined(separator: "・")
    }

    /// 種別と場所をまとめた1行表示。Figma の結果行2行目に対応する。
    var supplementaryText: String {
        let location = locationText
        return location.isEmpty ? kind.displayName : "\(kind.displayName)・\(location)"
    }

    /// VoiceOver が「名称、種別、建物、階」を一まとまりで読むためのラベル。
    /// 建物・階が未提供のときは「場所は未提供」と読み上げ、黙って省略しない。
    var accessibilityLabelText: String {
        var parts: [String] = [displayName, kind.displayName]
        if let buildingName {
            parts.append(buildingName)
        }
        if let floorName {
            parts.append(floorName)
        }
        if buildingName == nil && floorName == nil {
            parts.append("場所は未提供")
        }
        return parts.joined(separator: "、")
    }
}

/// 地点で行われるイベントの文脈。検索でイベントを選んだ場合に詳細へ引き継ぐ。
struct SpotEventContext: Equatable, Sendable {
    let eventID: String
    let title: String
    let scheduleText: String?
}

/// 地点詳細の表示内容。**生成できるのは `MapContentClient` だけ**。
/// これにより「探す」が独自の地点詳細を組み立てられない。
struct SpotDetailPresentation: Equatable, Sendable {
    let summary: SpotSummary
    let descriptionText: String?
    let scheduleText: String?
    let relatedEvent: SpotEventContext?

    init(
        summary: SpotSummary,
        descriptionText: String? = nil,
        scheduleText: String? = nil,
        relatedEvent: SpotEventContext? = nil
    ) {
        self.summary = summary
        self.descriptionText = descriptionText
        self.scheduleText = scheduleText
        self.relatedEvent = relatedEvent
    }
}
