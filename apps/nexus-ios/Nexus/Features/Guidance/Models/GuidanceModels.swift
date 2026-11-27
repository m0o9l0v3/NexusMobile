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
    /// `.help` / `.helpHealth` の本文冒頭に置く補足。
    let highlight: GuidanceHighlight?
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
    /// 学校原稿の品質管理に使う出典・確認日・確認者（E6-6 §4、U-3）。
    let confirmation: GuidanceConfirmation?
    /// Home の案内ショートカット（受付・困ったとき・アクセス）のどれから開くか。原稿の `homeShortcut`。
    /// 記事IDをコードに書かずに、Home から記事を選ぶための印。
    let homeShortcut: GuidanceHomeShortcut?

    init(
        id: GuidanceArticleID,
        kind: GuidanceArticleKind,
        navigationTitle: String,
        title: String,
        subtitle: String? = nil,
        highlight: GuidanceHighlight? = nil,
        sections: [GuidanceSection] = [],
        relatedPlaces: [GuidanceRelatedPlace] = [],
        unresolvedRelatedPlaceNote: String? = nil,
        accessSegments: [GuidanceAccessSegment] = [],
        faqItems: [GuidanceFAQItem] = [],
        officialContacts: [GuidanceOfficialContact] = [],
        confirmation: GuidanceConfirmation? = nil,
        homeShortcut: GuidanceHomeShortcut? = nil
    ) {
        self.id = id
        self.kind = kind
        self.navigationTitle = navigationTitle
        self.title = title
        self.subtitle = subtitle
        self.highlight = highlight
        self.sections = sections
        self.relatedPlaces = relatedPlaces
        self.unresolvedRelatedPlaceNote = unresolvedRelatedPlaceNote
        self.accessSegments = accessSegments
        self.faqItems = faqItems
        self.officialContacts = officialContacts
        self.confirmation = confirmation
        self.homeShortcut = homeShortcut
    }
}

/// Home の「案内」に並べるショートカット（Home v1.0 下書き B、Figma `2798:1550`）。
/// 並び順は宣言順。記事が無いショートカットは Home に出さない。
enum GuidanceHomeShortcut: String, CaseIterable, Equatable, Hashable, Sendable {
    case reception
    case help
    case access

    var title: String {
        switch self {
        case .reception: return "受付"
        case .help: return "困ったとき"
        case .access: return "アクセス"
        }
    }

    /// Figma の仮のアイコン（下書き §4 質問3 で確認中）。
    var systemImageName: String {
        switch self {
        case .reception: return "person.fill"
        case .help: return "info.circle"
        case .access: return "figure.walk"
        }
    }
}

/// 原稿の出典と、誰がいつ内容を確認したか（E6-6 §4）。3つとも欠けてはならない。
struct GuidanceConfirmation: Equatable, Sendable {
    /// 元にした資料の名前と日付、または原稿の提供元。
    let source: String
    let confirmedOn: GuidanceCalendarDate
    /// 確認した人。役割名でよい。
    let confirmer: String
}

/// 時刻を持たない暦日。原稿の確認日はタイムゾーンで日付がずれないよう、年月日のまま持つ。
struct GuidanceCalendarDate: Equatable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// `YYYY-MM-DD` の実在する日付だけを受け付ける。
    init?(isoDate: String) {
        let parts = isoDate.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard DateComponents(year: year, month: month, day: day).isValidDate(in: calendar) else {
            return nil
        }

        self.year = year
        self.month = month
        self.day = day
    }
}

/// 案内原稿の補足文。
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

// MARK: - 取得結果と画面状態

enum GuidanceTopFetchResult: Equatable, Sendable {
    case fresh(GuidanceTopSnapshot)
    case empty(NexusStateMessage)
    case saved(GuidanceTopSnapshot, NexusSavedMetadata)
}

enum GuidanceArticleFetchResult: Equatable, Sendable {
    case fresh(GuidanceArticle)
    case saved(GuidanceArticle, NexusSavedMetadata)
    /// 指定された記事の原稿が未提供。
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
