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
        var seenShortcuts: Set<String> = []

        for (index, dto) in articleDTOs.enumerated() {
            var validator = ArticleValidator(index: index, rawID: dto.id)
            if let id = dto.id, !seenIDs.insert(id).inserted {
                validator.report(.id, "記事ID「\(id)」が重複しています")
            }
            if let shortcut = dto.homeShortcut, !seenShortcuts.insert(shortcut).inserted {
                validator.report(.homeShortcut, "Home のショートカット「\(shortcut)」は1記事にだけ付けられます")
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

    var topFetchResult: GuidanceTopFetchResult {
        .fresh(GuidanceTopSnapshot(
            sections: GuidanceMenuSection.Kind.allCases.map { kind in
                GuidanceMenuSection(kind: kind, items: kind.topics.map { topic in
                    GuidanceMenuItem(topic: topic, articleID: article(for: topic)?.id)
                })
            }
        ))
    }

    private func article(for topic: GuidanceMenuTopic) -> GuidanceArticle? {
        // Home に印のある記事は目次からも同じ ID で開く。
        let matches = articles.filter { $0.menuTopic == topic }
        return matches.first { $0.homeShortcut != nil }
            ?? matches.first { $0.id == topic.defaultArticleID }
            ?? matches.first
            ?? (topic == .about ? Self.aboutArticle : nil)
    }

    private static let aboutArticle = GuidanceArticle(
        id: GuidanceMenuTopic.about.defaultArticleID,
        kind: .standard,
        navigationTitle: GuidanceMenuTopic.about.title,
        title: GuidanceMenuTopic.about.title,
        sections: [
            GuidanceSection(
                id: "gsi-attribution",
                heading: "国土地理院の測量成果",
                paragraphs: GSIAttribution.aboutParagraphs
            ),
            GuidanceSection(
                id: "privacy",
                heading: "プライバシー",
                paragraphs: [
                    "現在地はアプリを使っている間だけ端末内で利用し、Nexus のサーバーや第三者へ送信・保存しません。位置情報を許可しない場合も、手動で出発地を選んで経路案内を使えます。",
                    "氏名やメールアドレスなどの個人情報の登録は不要で、広告・行動トラッキングは行いません。",
                ]
            ),
        ],
        officialContacts: [
            GuidanceOfficialContact(
                id: "privacyPolicy",
                kind: .web,
                label: "プライバシーポリシー",
                url: URL(string: "https://www.nexus-app.jp/privacy/")!
            ),
            GuidanceOfficialContact(
                id: "officialSite",
                kind: .web,
                label: "Nexus 公式サイト・サポート",
                url: URL(string: "https://www.nexus-app.jp/")!
            ),
        ]
    )

    /// Home の案内ショートカット（Home v1.0 下書き B）。`homeShortcut` を持つ記事だけを、受付・困ったとき・アクセスの順に。
    var homeShortcuts: [HomeGuidanceShortcut] {
        GuidanceHomeShortcut.allCases.compactMap { shortcut in
            articles.first { $0.homeShortcut == shortcut }
                .map { HomeGuidanceShortcut(shortcut: shortcut, articleID: $0.id) }
        }
    }

    func articleFetchResult(for id: GuidanceArticleID) -> GuidanceArticleFetchResult {
        let article = articles.first { $0.id == id }
            ?? (id == Self.aboutArticle.id ? Self.aboutArticle : nil)
        guard let article else {
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
        case officialContacts
        case source
        case confirmedOn
        case confirmer
        case homeShortcut
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

private extension GuidanceArticle {
    var menuTopic: GuidanceMenuTopic? {
        homeShortcut.flatMap { GuidanceMenuTopic(rawValue: $0.rawValue) }
            ?? GuidanceMenuTopic(rawValue: id.rawValue)
            ?? kind.menuTopic
    }
}

private extension GuidanceArticleKind {
    var menuTopic: GuidanceMenuTopic? {
        switch self {
        case .standard: nil
        case .help: .help
        case .helpHealth: .health
        case .access: .access
        case .faq: .faq
        }
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
    let officialContacts: [OfficialContactDTO]?
    let accessSegments: [AccessSegmentDTO]?
    let faqItems: [FAQItemDTO]?
    let source: String?
    let confirmation: ConfirmationDTO?
    /// 任意。`reception` / `help` / `access`。Home のショートカットから開く記事に付ける。
    let homeShortcut: String?
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

private struct OfficialContactDTO: Decodable {
    let id: String
    let kind: String
    let label: String
    let url: String
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

        var homeShortcut: GuidanceHomeShortcut?
        if let rawShortcut = dto.homeShortcut {
            homeShortcut = GuidanceHomeShortcut(rawValue: rawShortcut)
            if homeShortcut == nil {
                report(.homeShortcut, "「\(rawShortcut)」は Home のショートカットではありません（reception / help / access）")
            }
        }

        let sections = mapSections(dto.sections ?? [])
        let relatedPlaces = mapRelatedSpots(dto.relatedSpots ?? [])
        let officialContacts = mapOfficialContacts(dto.officialContacts ?? [])
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
            sections: sections,
            relatedPlaces: relatedPlaces,
            accessSegments: accessSegments,
            faqItems: faqItems,
            officialContacts: officialContacts,
            confirmation: GuidanceConfirmation(source: source, confirmedOn: confirmedOn, confirmer: confirmer),
            homeShortcut: homeShortcut
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

    private mutating func mapOfficialContacts(_ dtos: [OfficialContactDTO]) -> [GuidanceOfficialContact] {
        var seenIDs: Set<String> = []
        return dtos.compactMap { dto in
            guard nonBlank(dto.id) != nil, seenIDs.insert(dto.id).inserted else {
                report(.officialContacts, "連絡先の id は空にできず、記事内で一意である必要があります（「\(dto.id)」）")
                return nil
            }
            guard let kind = GuidanceOfficialContact.Kind(rawValue: dto.kind) else {
                report(.officialContacts, "連絡先「\(dto.id)」の kind は phone / web のいずれかです")
                return nil
            }
            guard nonBlank(dto.label) != nil else {
                report(.officialContacts, "連絡先「\(dto.id)」に label がありません")
                return nil
            }
            guard let url = officialContactURL(dto.url, kind: kind) else {
                report(.officialContacts, "連絡先「\(dto.id)」の url は \(kind.rawValue) の形式に合いません")
                return nil
            }
            return GuidanceOfficialContact(id: dto.id, kind: kind, label: dto.label, url: url)
        }
    }

    private func officialContactURL(_ rawURL: String, kind: GuidanceOfficialContact.Kind) -> URL? {
        guard let url = URL(string: rawURL) else { return nil }
        switch kind {
        case .phone:
            guard url.scheme?.lowercased() == "tel" else { return nil }
            let number = rawURL.dropFirst("tel:".count).unicodeScalars
            let digits = CharacterSet(charactersIn: "0123456789")
            let allowed = digits.union(CharacterSet(charactersIn: "+-()"))
            guard number.contains(where: digits.contains), number.allSatisfy(allowed.contains) else { return nil }
        case .web:
            guard url.scheme?.lowercased() == "https", nonBlank(url.host) != nil else { return nil }
        }
        return url
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
