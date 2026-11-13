import Foundation

/// アプリに同梱する案内原稿（E6-6 案A、#86）。
///
/// 原稿ファイルは `Nexus/Resources/Guidance/GuidanceArticles.json`。
/// 形式と検証規則は `docs/implementation/issue-86-guidance-articles-format.md`。
///
/// 1件でも公開条件（出典・確認日・確認者・本文など）を欠く記事があれば、**ファイル全体を読み込まない**。
/// 欠けた記事だけを黙って落とすと、目次から記事が消えたことに誰も気付かないため。
struct BundledGuidanceCatalog: Equatable, Sendable {
    static let resourceName = "GuidanceArticles"
    static let resourceExtension = "json"
    static let supportedSchemaVersion = 1

    /// ファイルに書かれた順の、公開条件を満たした記事。
    let articles: [GuidanceArticle]

    static func decode(_ data: Data) throws -> BundledGuidanceCatalog {
        let file: FileDTO
        do {
            file = try JSONDecoder().decode(FileDTO.self, from: data)
        } catch {
            throw BundledGuidanceCatalogError.malformed(String(describing: error))
        }

        guard let version = file.schemaVersion else {
            throw BundledGuidanceCatalogError.malformed("schemaVersion がありません")
        }
        guard version == supportedSchemaVersion else {
            throw BundledGuidanceCatalogError.unsupportedSchemaVersion(version)
        }
        guard let articleDTOs = file.articles else {
            throw BundledGuidanceCatalogError.malformed("articles がありません（原稿が無いときは空の配列にする）")
        }

        var issues: [GuidanceArticleIssue] = []
        var articles: [GuidanceArticle] = []
        var seenIDs: Set<String> = []

        for (index, dto) in articleDTOs.enumerated() {
            var validator = ArticleValidator(index: index, rawID: dto.id)
            if let id = dto.id, !seenIDs.insert(id).inserted {
                validator.report(.id, "記事ID「\(id)」が重複しています")
            }
            if let article = validator.validate(dto) {
                articles.append(article)
            }
            issues.append(contentsOf: validator.issues)
        }

        guard issues.isEmpty else {
            throw BundledGuidanceCatalogError.invalidArticles(issues)
        }
        return BundledGuidanceCatalog(articles: articles)
    }

    // MARK: - GuidanceClient への受け渡し

    static let emptyMessage = NexusStateMessage(
        title: "案内の原稿はまだありません",
        detail: "内容の確認が済んだ案内から、アプリの更新で掲載します。",
        systemImageName: "doc.text"
    )

    /// 案内トップ。正式な目次（#86「正式な目次と分類」）が決まるまでは、
    /// 困ったとき（`.help` / `.helpHealth`）を一覧上部に、それ以外をファイル順に並べるだけにする。
    var topFetchResult: GuidanceTopFetchResult {
        guard !articles.isEmpty else {
            return .empty(Self.emptyMessage)
        }

        let trouble = articles.filter { $0.kind == .help || $0.kind == .helpHealth }
        let others = articles.filter { $0.kind != .help && $0.kind != .helpHealth }

        return .fresh(
            GuidanceTopSnapshot(
                troubleItems: trouble.map(\.menuItem),
                sections: others.isEmpty ? [] : [
                    GuidanceMenuSection(id: "articles", heading: "案内一覧", items: others.map(\.menuItem))
                ],
                // 内蔵の原稿に「オフライン保存版」「最新確認不可」は当てはまらない（E6-6 §3）。
                // 確認日は各記事に出す。
                updateStatus: nil
            )
        )
    }

    func articleFetchResult(for id: GuidanceArticleID) -> GuidanceArticleFetchResult {
        guard let article = articles.first(where: { $0.id == id }) else {
            return .notProvided(id)
        }
        return .fresh(article)
    }
}

enum BundledGuidanceCatalogError: Error, Equatable, CustomStringConvertible {
    case resourceMissing
    case malformed(String)
    case unsupportedSchemaVersion(Int)
    case invalidArticles([GuidanceArticleIssue])

    var description: String {
        switch self {
        case .resourceMissing:
            return "案内原稿ファイルがアプリに同梱されていません"
        case .malformed(let reason):
            return "案内原稿ファイルを読めません: \(reason)"
        case .unsupportedSchemaVersion(let version):
            return "案内原稿ファイルの schemaVersion \(version) には対応していません"
        case .invalidArticles(let issues):
            return (["公開条件を満たさない記事があります:"] + issues.map { "- \($0)" })
                .joined(separator: "\n")
        }
    }
}

/// 公開条件を満たさない項目1件。
struct GuidanceArticleIssue: Equatable, Sendable, CustomStringConvertible {
    enum Field: String, Equatable, Sendable {
        case id
        case kind
        case navigationTitle
        case title
        case body
        case relatedSpots
        case source
        case confirmedOn
        case confirmer
    }

    /// `articles` 配列での位置（0始まり）。ID が欠けた記事も特定できるようにする。
    let articleIndex: Int
    let articleID: String?
    let field: Field
    let reason: String

    var description: String {
        "articles[\(articleIndex)]（\(articleID ?? "ID なし")）\(field.rawValue): \(reason)"
    }
}

private extension GuidanceArticleKind {
    /// 正式な目次が決まるまでの仮の記号。記事IDでは分けない。
    var menuSystemImageName: String {
        switch self {
        case .standard: return "doc.text"
        case .help: return "questionmark.circle"
        case .helpHealth: return "cross.case"
        case .access: return "tram"
        case .faq: return "questionmark.bubble"
        }
    }
}

private extension GuidanceArticle {
    var menuItem: GuidanceMenuItem {
        GuidanceMenuItem(id: id, title: navigationTitle, systemImageName: kind.menuSystemImageName)
    }
}

// MARK: - ファイルの形（v1）

/// 欠けた項目を復号失敗ではなく「どの記事の何が無いか」で報告するため、記事の必須項目は Optional で受ける。
private struct FileDTO: Decodable {
    let schemaVersion: Int?
    let articles: [ArticleDTO]?
}

private struct ArticleDTO: Decodable {
    let id: String?
    let kind: String?
    let navigationTitle: String?
    let title: String?
    let subtitle: String?
    let highlight: HighlightDTO?
    let sections: [SectionDTO]?
    let relatedSpots: [RelatedSpotDTO]?
    let accessSegments: [AccessSegmentDTO]?
    let faqItems: [FAQItemDTO]?
    let source: String?
    let confirmation: ConfirmationDTO?
}

private struct SectionDTO: Decodable {
    let id: String
    let heading: String?
    let paragraphs: [String]
}

private struct RelatedSpotDTO: Decodable {
    let canonicalSpotId: String
    let displayName: String
    let supplementaryText: String?
}

private struct HighlightDTO: Decodable {
    let tone: String
    let systemImageName: String
    let title: String
    let body: String
}

private struct AccessSegmentDTO: Decodable {
    let mode: String
    let sections: [SectionDTO]
    let relatedSpots: [RelatedSpotDTO]?
}

private struct FAQItemDTO: Decodable {
    let id: String
    let category: String?
    let question: String
    let answerParagraphs: [String]
}

private struct ConfirmationDTO: Decodable {
    let confirmedOn: String?
    let confirmer: String?
}

// MARK: - 検証

private struct ArticleValidator {
    let index: Int
    let rawID: String?
    private(set) var issues: [GuidanceArticleIssue] = []

    init(index: Int, rawID: String?) {
        self.index = index
        self.rawID = rawID
    }

    mutating func report(_ field: GuidanceArticleIssue.Field, _ reason: String) {
        issues.append(GuidanceArticleIssue(articleIndex: index, articleID: rawID, field: field, reason: reason))
    }

    /// 公開条件を満たせば記事を返す。満たさなければ `issues` に理由を積んで nil。
    mutating func validate(_ dto: ArticleDTO) -> GuidanceArticle? {
        let id = required(dto.id, .id)
        let navigationTitle = required(dto.navigationTitle, .navigationTitle)
        let title = required(dto.title, .title)

        var kind: GuidanceArticleKind?
        if let rawKind = required(dto.kind, .kind) {
            kind = GuidanceArticleKind(rawValue: rawKind)
            if kind == nil {
                report(.kind, "「\(rawKind)」は記事の種類ではありません")
            }
        }

        let source = required(dto.source, .source)
        let confirmer = required(dto.confirmation?.confirmer, .confirmer)
        var confirmedOn: GuidanceCalendarDate?
        if let rawDate = required(dto.confirmation?.confirmedOn, .confirmedOn) {
            confirmedOn = GuidanceCalendarDate(isoDate: rawDate)
            if confirmedOn == nil {
                report(.confirmedOn, "「\(rawDate)」は YYYY-MM-DD の実在する日付ではありません")
            }
        }

        let sections = mapSections(dto.sections ?? [])
        let relatedPlaces = mapRelatedSpots(dto.relatedSpots ?? [])
        let highlight = mapHighlight(dto.highlight)
        let accessSegments = mapAccessSegments(dto.accessSegments ?? [])
        let faqItems = mapFAQItems(dto.faqItems ?? [])

        if let kind {
            checkBody(kind: kind, sections: sections, accessSegments: accessSegments, faqItems: faqItems)
        }

        guard issues.isEmpty,
              let id, let kind, let navigationTitle, let title,
              let source, let confirmer, let confirmedOn
        else {
            return nil
        }

        return GuidanceArticle(
            id: GuidanceArticleID(rawValue: id),
            kind: kind,
            navigationTitle: navigationTitle,
            title: title,
            subtitle: nonBlank(dto.subtitle),
            highlight: highlight,
            updateStatus: .normal,
            sections: sections,
            relatedPlaces: relatedPlaces,
            accessSegments: accessSegments,
            faqItems: faqItems,
            confirmation: GuidanceConfirmation(source: source, confirmedOn: confirmedOn, confirmer: confirmer)
        )
    }

    private mutating func required(_ value: String?, _ field: GuidanceArticleIssue.Field) -> String? {
        guard let value = nonBlank(value) else {
            report(field, "必須です")
            return nil
        }
        return value
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    private mutating func checkBody(
        kind: GuidanceArticleKind,
        sections: [GuidanceSection],
        accessSegments: [GuidanceAccessSegment],
        faqItems: [GuidanceFAQItem]
    ) {
        switch kind {
        case .standard, .help, .helpHealth:
            if sections.isEmpty { report(.body, "sections が1つも無い記事は公開しません") }
        case .access:
            if accessSegments.isEmpty { report(.body, "accessSegments が1つも無いアクセス記事は公開しません") }
        case .faq:
            if faqItems.isEmpty { report(.body, "faqItems が1つも無い FAQ は公開しません") }
        }
    }

    /// 段落の id は画面で `ForEach` の識別子になるため、同じ並びの中で重複させない。
    private mutating func mapSections(_ dtos: [SectionDTO]) -> [GuidanceSection] {
        var seenIDs: Set<String> = []
        return dtos.compactMap { dto in
            guard seenIDs.insert(dto.id).inserted else {
                report(.body, "section の id「\(dto.id)」が重複しています")
                return nil
            }
            let paragraphs = dto.paragraphs.compactMap(nonBlank)
            guard nonBlank(dto.id) != nil, !paragraphs.isEmpty else {
                report(.body, "section「\(dto.id)」に id か段落がありません")
                return nil
            }
            return GuidanceSection(id: dto.id, heading: nonBlank(dto.heading), paragraphs: paragraphs)
        }
    }

    /// 確定した canonical ID だけを書く取り決め（E6-6 §4）。空の ID は無反応のボタンになるので拒否する。
    private mutating func mapRelatedSpots(_ dtos: [RelatedSpotDTO]) -> [GuidanceRelatedPlace] {
        dtos.compactMap { dto in
            guard nonBlank(dto.canonicalSpotId) != nil, nonBlank(dto.displayName) != nil else {
                report(.relatedSpots, "canonicalSpotId と displayName は必須です（未確定の地点は書かない）")
                return nil
            }
            return GuidanceRelatedPlace(
                canonicalSpotID: CanonicalSpotID(rawValue: dto.canonicalSpotId),
                displayName: dto.displayName,
                supplementaryText: nonBlank(dto.supplementaryText)
            )
        }
    }

    private mutating func mapHighlight(_ dto: HighlightDTO?) -> GuidanceHighlight? {
        guard let dto else { return nil }
        guard let tone = GuidanceHighlight.Tone(rawValue: dto.tone),
              nonBlank(dto.title) != nil, nonBlank(dto.body) != nil
        else {
            report(.body, "highlight の tone（informational / caution）・title・body を確認してください")
            return nil
        }
        return GuidanceHighlight(
            tone: tone,
            systemImageName: dto.systemImageName,
            title: dto.title,
            bodyText: dto.body
        )
    }

    /// 画面は交通手段ごとに切り替えを1つだけ作り、同じ mode の2件目以降には到達できない。
    /// そのため mode の重複は拒否する。
    private mutating func mapAccessSegments(_ dtos: [AccessSegmentDTO]) -> [GuidanceAccessSegment] {
        var seenModes: Set<GuidanceAccessMode> = []
        return dtos.compactMap { dto in
            guard let mode = GuidanceAccessMode(rawValue: dto.mode) else {
                report(.body, "accessSegments の mode「\(dto.mode)」は train / bus / car ではありません")
                return nil
            }
            guard seenModes.insert(mode).inserted else {
                report(.body, "accessSegments の mode「\(dto.mode)」が重複しています（交通手段ごとに1つ）")
                return nil
            }
            let sections = mapSections(dto.sections)
            guard !sections.isEmpty else {
                report(.body, "accessSegments「\(dto.mode)」に sections がありません")
                return nil
            }
            return GuidanceAccessSegment(
                mode: mode,
                sections: sections,
                relatedPlaces: mapRelatedSpots(dto.relatedSpots ?? [])
            )
        }
    }

    private mutating func mapFAQItems(_ dtos: [FAQItemDTO]) -> [GuidanceFAQItem] {
        var seenIDs: Set<String> = []
        return dtos.compactMap { dto in
            guard seenIDs.insert(dto.id).inserted else {
                report(.body, "faqItems の id「\(dto.id)」が重複しています")
                return nil
            }
            let answer = dto.answerParagraphs.compactMap(nonBlank)
            guard nonBlank(dto.id) != nil, nonBlank(dto.question) != nil, !answer.isEmpty else {
                report(.body, "faqItems「\(dto.id)」に id・question・answerParagraphs がありません")
                return nil
            }
            return GuidanceFAQItem(
                id: dto.id,
                category: nonBlank(dto.category),
                question: dto.question,
                answerParagraphs: answer
            )
        }
    }
}
