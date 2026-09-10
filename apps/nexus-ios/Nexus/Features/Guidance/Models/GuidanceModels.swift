import Foundation

/// 案内記事の識別子。canonical ID と同じく大文字・小文字を保持し、表示名から生成しない。
struct GuidanceArticleID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// 詳細画面のレイアウトを決めるのは**記事の種類**であって記事IDではない。
/// 本番コードに記事IDのハードコードを置かないための型。
/// Figma の5画面（`2723:2622` / `2723:2675` / `2723:2824` / `2723:2729` / `2723:2793`）に対応する。
enum GuidanceArticleKind: String, Equatable, Hashable, Sendable, CaseIterable {
    /// `2723:2622` GuidanceDetail / Standard（受付案内など）
    case standard
    /// `2723:2675` GuidanceDetail / Help（道に迷った）
    case help
    /// `2723:2824` GuidanceDetail / Help Health（体調が悪い）
    case helpHealth
    /// `2723:2729` GuidanceDetail / Access（電車・バス・自動車）
    case access
    /// `2723:2793` GuidanceDetail / FAQ
    case faq
}

/// Figma `2720:5366` Guidance/Common/UpdateStatus の3状態。
///
/// この値は**クライアントが返すペイロードの一部**であり、ストアが到達性から推測しない。
/// 推測すると、承認されていないネットワーク／キャッシュのモデルを発明することになる。
enum GuidanceUpdateStatus: String, Equatable, Hashable, Sendable, CaseIterable {
    /// `2720:5360` State=Normal
    case normal
    /// `2720:5362` State=Offline
    case offline
    /// `2720:5364` State=Unavailable
    case unavailable

    var message: String {
        switch self {
        case .normal:
            return "更新状況：内容確認中"
        case .offline:
            return "オフライン保存版・更新状況は確認できません"
        case .unavailable:
            return "最新情報を確認できません・保存済みの内容を表示"
        }
    }

    var systemImageName: String {
        switch self {
        case .normal:
            return "clock"
        case .offline:
            return "wifi.slash"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }
}

/// Figma `2720:5367` Guidance/Common/ArticleSection。
struct GuidanceSection: Identifiable, Equatable, Sendable {
    let id: String
    let heading: String?
    let paragraphs: [String]

    init(id: String, heading: String? = nil, paragraphs: [String]) {
        self.id = id
        self.heading = heading
        self.paragraphs = paragraphs
    }
}

/// Figma `2720:5370` Guidance/Common/RelatedPlace。
///
/// canonical ID が確定していない関連地点は**この型を作らない**。
/// Implementation Notes（`2730:2942`）に「本館1階の canonical ID 未確定のため地点選択は行わない」とあり、
/// #86 の受入条件も「未提供なら無反応ボタンを出さない」と定めているため、
/// ID が無いときは `GuidanceArticle.unresolvedRelatedPlaceNote` で説明表示に落とす。
struct GuidanceRelatedPlace: Identifiable, Equatable, Sendable {
    let canonicalSpotID: CanonicalSpotID
    let displayName: String
    let supplementaryText: String?

    var id: CanonicalSpotID { canonicalSpotID }

    init(canonicalSpotID: CanonicalSpotID, displayName: String, supplementaryText: String? = nil) {
        self.canonicalSpotID = canonicalSpotID
        self.displayName = displayName
        self.supplementaryText = supplementaryText
    }
}

/// Figma `2722:5533` Guidance/FAQ/Row。
struct GuidanceFAQItem: Identifiable, Equatable, Sendable {
    let id: String
    let category: String?
    let question: String
    let answerParagraphs: [String]

    init(id: String, category: String? = nil, question: String, answerParagraphs: [String]) {
        self.id = id
        self.category = category
        self.question = question
        self.answerParagraphs = answerParagraphs
    }
}

/// Figma `2722:5507` Guidance/Access/TransportPicker の Variant。
enum GuidanceAccessMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case train
    case bus
    case car

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .train:
            return "電車"
        case .bus:
            return "バス"
        case .car:
            return "自動車"
        }
    }
}

struct GuidanceAccessSegment: Identifiable, Equatable, Sendable {
    let mode: GuidanceAccessMode
    let sections: [GuidanceSection]
    let relatedPlaces: [GuidanceRelatedPlace]

    var id: GuidanceAccessMode { mode }

    init(
        mode: GuidanceAccessMode,
        sections: [GuidanceSection],
        relatedPlaces: [GuidanceRelatedPlace] = []
    ) {
        self.mode = mode
        self.sections = sections
        self.relatedPlaces = relatedPlaces
    }
}

/// 確認済みの公式連絡先。未確認のものは値を作らない（#86「確認済みのみ表示」）。
struct GuidanceOfficialContact: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case phone
        case web
    }

    let id: String
    let kind: Kind
    let label: String
    let url: URL
}

struct GuidanceArticle: Identifiable, Equatable, Sendable {
    let id: GuidanceArticleID
    let kind: GuidanceArticleKind
    /// ナビゲーションバーに出す短い表題（Figma `2720:2543`）。
    let navigationTitle: String
    /// 本文先頭の大見出し。
    let title: String
    let subtitle: String?
    /// `.help` / `.helpHealth` の冒頭カードに出す強調文。
    let highlight: GuidanceHighlight?
    let updateStatus: GuidanceUpdateStatus
    let sections: [GuidanceSection]
    let relatedPlaces: [GuidanceRelatedPlace]
    /// canonical ID が未確定で関連地点を提示できない場合の説明。
    /// `relatedPlaces` が空でこれが非 nil のとき、ボタンを出さずこの文だけを表示する。
    let unresolvedRelatedPlaceNote: String?
    /// `.access` のときだけ埋まる。
    let accessSegments: [GuidanceAccessSegment]
    /// `.faq` のときだけ埋まる。
    let faqItems: [GuidanceFAQItem]
    let officialContacts: [GuidanceOfficialContact]

    init(
        id: GuidanceArticleID,
        kind: GuidanceArticleKind,
        navigationTitle: String,
        title: String,
        subtitle: String? = nil,
        highlight: GuidanceHighlight? = nil,
        updateStatus: GuidanceUpdateStatus,
        sections: [GuidanceSection] = [],
        relatedPlaces: [GuidanceRelatedPlace] = [],
        unresolvedRelatedPlaceNote: String? = nil,
        accessSegments: [GuidanceAccessSegment] = [],
        faqItems: [GuidanceFAQItem] = [],
        officialContacts: [GuidanceOfficialContact] = []
    ) {
        self.id = id
        self.kind = kind
        self.navigationTitle = navigationTitle
        self.title = title
        self.subtitle = subtitle
        self.highlight = highlight
        self.updateStatus = updateStatus
        self.sections = sections
        self.relatedPlaces = relatedPlaces
        self.unresolvedRelatedPlaceNote = unresolvedRelatedPlaceNote
        self.accessSegments = accessSegments
        self.faqItems = faqItems
        self.officialContacts = officialContacts
    }
}

/// `.help` / `.helpHealth` 冒頭の淡い下地カード。
struct GuidanceHighlight: Equatable, Sendable {
    enum Tone: String, Equatable, Sendable {
        case informational
        case caution
    }

    let tone: Tone
    let systemImageName: String
    let title: String
    let bodyText: String
}

// MARK: - 案内トップ（Figma 2595:760）

struct GuidanceMenuItem: Identifiable, Equatable, Sendable {
    let id: GuidanceArticleID
    let title: String
    let detail: String?
    let systemImageName: String

    init(id: GuidanceArticleID, title: String, detail: String? = nil, systemImageName: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImageName = systemImageName
    }
}

/// 「本日のご案内」カード（Figma `2599:2192` Section / Today）。
///
/// 固定の開催・受付時間だけを扱う。「受付中」「LIVE」「混雑」など、
/// 実際の進行状況を示す表示は v1.0 対象外（v04 C10）。
struct GuidanceTodayCard: Equatable, Sendable {
    let title: String
    /// 「受付 9:00〜」のような固定時間。
    let scheduleText: String?
    /// 「本館1階」のような場所名。
    let locationText: String?
    let primaryActionTitle: String
    let primaryArticleID: GuidanceArticleID?
    /// 「マップで見る」の遷移先。canonical ID が未確定の間は nil にして、
    /// 無反応のボタンを出さない（Implementation Notes `2730:2942` / #86）。
    let mapSpotID: CanonicalSpotID?

    init(
        title: String,
        scheduleText: String? = nil,
        locationText: String? = nil,
        primaryActionTitle: String,
        primaryArticleID: GuidanceArticleID? = nil,
        mapSpotID: CanonicalSpotID? = nil
    ) {
        self.title = title
        self.scheduleText = scheduleText
        self.locationText = locationText
        self.primaryActionTitle = primaryActionTitle
        self.primaryArticleID = primaryArticleID
        self.mapSpotID = mapSpotID
    }
}

/// 見出し付きのグループ化リスト（Figma `2599:2195` 来場案内 / `2599:2196` 学校を知る）。
struct GuidanceMenuSection: Identifiable, Equatable, Sendable {
    let id: String
    let heading: String
    let items: [GuidanceMenuItem]
}

struct GuidanceTopSnapshot: Equatable, Sendable {
    let todayCard: GuidanceTodayCard?
    /// 「よく使う案内」2×2グリッド（Figma `2599:2193`）。
    let frequentItems: [GuidanceMenuItem]
    /// 「困ったとき」。一覧上部に置く（#86 G02）。
    let troubleItems: [GuidanceMenuItem]
    /// 「来場案内」「学校を知る」などのグループ化リスト。
    let sections: [GuidanceMenuSection]
    let updateStatus: GuidanceUpdateStatus

    init(
        todayCard: GuidanceTodayCard? = nil,
        frequentItems: [GuidanceMenuItem] = [],
        troubleItems: [GuidanceMenuItem] = [],
        sections: [GuidanceMenuSection] = [],
        updateStatus: GuidanceUpdateStatus
    ) {
        self.todayCard = todayCard
        self.frequentItems = frequentItems
        self.troubleItems = troubleItems
        self.sections = sections
        self.updateStatus = updateStatus
    }
}

// MARK: - 取得結果と画面状態

enum GuidanceTopFetchResult: Equatable, Sendable {
    case fresh(GuidanceTopSnapshot)
    case empty(NexusStateMessage)
    case saved(GuidanceTopSnapshot, NexusSavedMetadata)
}

enum GuidanceArticleFetchResult: Equatable, Sendable {
    case fresh(GuidanceArticle)
    case saved(GuidanceArticle, NexusSavedMetadata)
    /// 目次には載っているが原稿が未提供。他の記事へフォールバックしない。
    case notProvided(GuidanceArticleID)
}

enum GuidanceTopViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(GuidanceTopSnapshot)
    case empty(NexusStateMessage)
    case failed(NexusStateMessage)
    case saved(GuidanceTopSnapshot, NexusSavedMetadata)
}

enum GuidanceArticleViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(GuidanceArticle)
    case notProvided(GuidanceArticleID)
    case failed(NexusStateMessage)
    case saved(GuidanceArticle, NexusSavedMetadata)
}
