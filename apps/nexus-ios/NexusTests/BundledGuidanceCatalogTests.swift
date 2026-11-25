import XCTest
@testable import Nexus

/// 同梱の案内原稿（E6-6 案A、#86）の復号・公開条件の検証・空の状態。
///
/// 本文・地点名などには試験用の値を使う。
@MainActor
final class BundledGuidanceCatalogTests: XCTestCase {

    // MARK: - 同梱ファイルの検証（配布物の検証工程）

    /// 同梱の `GuidanceArticles.json` が公開条件を満たすこと。
    /// 原稿を足す PR で出典・確認日・確認者が欠けていれば、ここで試験が落ちる。
    func testShippedGuidanceFileIsPublishable() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: BundledGuidanceCatalog.resourceName,
                withExtension: BundledGuidanceCatalog.resourceExtension
            ),
            "GuidanceArticles.json がアプリに同梱されていない"
        )
        do {
            _ = try BundledGuidanceCatalog.decode(Data(contentsOf: url))
        } catch {
            XCTFail("同梱の案内原稿が公開条件を満たさない:\n\(error)")
        }
    }

    func testShippedGuidanceFileCoversAllTenSchoolTopicsAndHomeShortcuts() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: BundledGuidanceCatalog.resourceName,
                withExtension: BundledGuidanceCatalog.resourceExtension
            )
        )
        let catalog = try BundledGuidanceCatalog.decode(Data(contentsOf: url))
        let schoolArticleIDs = [
            "health", "help", "reception", "access", "facility", "manners",
            "department", "schoolLife", "dormitory", "faq"
        ]
        XCTAssertEqual(catalog.articles.count, 10)
        XCTAssertEqual(catalog.articles.map(\.id.rawValue), schoolArticleIDs)

        guard case .fresh(let snapshot) = catalog.topFetchResult else {
            return XCTFail("同梱原稿の目次を取得できなかった")
        }
        XCTAssertEqual(snapshot.sections.map { $0.items.count }, [2, 4, 5])
        let menuIDs = snapshot.sections.flatMap(\.items).map { $0.articleID?.rawValue }
        XCTAssertEqual(menuIDs, schoolArticleIDs + ["about"])
        XCTAssertEqual(catalog.homeShortcuts.map(\.shortcut), [.reception, .help, .access])

        let access = try XCTUnwrap(catalog.articles.first { $0.id.rawValue == "access" })
        XCTAssertEqual(access.accessSegments.map(\.mode), [.train, .bus, .car])
        XCTAssertEqual(access.sections.map(\.id), ["address", "air"])
        let faq = try XCTUnwrap(catalog.articles.first { $0.id.rawValue == "faq" })
        XCTAssertEqual(faq.faqItems.count, 12)
        let health = try XCTUnwrap(catalog.articles.first { $0.id.rawValue == "health" })
        XCTAssertEqual(health.officialContacts.map(\.id), ["faq"])
        XCTAssertEqual(health.officialContacts.map(\.kind), [.web])

        let confirmedOn = try XCTUnwrap(GuidanceCalendarDate(isoDate: "2026-11-25"))
        let canonicalBuildingIDs: Set<String> = [
            "ab", "amh", "aptr", "ar", "ctc_main", "ctc2", "dh", "dvh",
            "hgr_a", "hgr_b", "lbh", "mb", "ptb", "sab"
        ]
        for article in catalog.articles {
            XCTAssertEqual(article.confirmation?.confirmedOn, confirmedOn, article.id.rawValue)
            let places = article.relatedPlaces + article.accessSegments.flatMap(\.relatedPlaces)
            for place in places {
                let id = place.canonicalSpotID.rawValue
                XCTAssertTrue(canonicalBuildingIDs.contains(id), "\(article.id.rawValue) の地点 \(id) は E1-1 にありません")
            }
        }
    }

    // MARK: - 復号

    func testDecodesStandardArticleWithConfirmation() throws {
        let catalog = try decode(articles: [standardArticleJSON(id: "Reception_A")])

        let article = try XCTUnwrap(catalog.articles.first)
        // 大文字・小文字を保持する。
        XCTAssertEqual(article.id, GuidanceArticleID(rawValue: "Reception_A"))
        XCTAssertEqual(article.kind, .standard)
        XCTAssertEqual(article.navigationTitle, "試験表題")
        XCTAssertEqual(article.sections, [
            GuidanceSection(id: "s1", heading: "試験見出し", paragraphs: ["試験段落"])
        ])
        XCTAssertEqual(article.relatedPlaces, [
            GuidanceRelatedPlace(canonicalSpotID: CanonicalSpotID(rawValue: "test_spot_001"), displayName: "試験地点")
        ])
        XCTAssertTrue(article.officialContacts.isEmpty)
        let confirmation = try XCTUnwrap(article.confirmation)
        XCTAssertEqual(confirmation.source, "試験資料 2026-11-01")
        XCTAssertEqual(confirmation.confirmer, "試験確認者")
        XCTAssertEqual(confirmation.confirmedOn.year, 2026)
        XCTAssertEqual(confirmation.confirmedOn.month, 11)
        XCTAssertEqual(confirmation.confirmedOn.day, 13)
    }

    func testDecodesOfficialContactsInOrder() throws {
        let phoneURL = "tel:0120-87-8622"
        let webURL = "https://www.jaa-tech.jp/"
        var article = standardArticleJSON(id: "help")
        article["officialContacts"] = [
            ["id": "office", "kind": "phone", "label": "代表電話", "url": phoneURL],
            ["id": "site", "kind": "web", "label": "公式サイト", "url": webURL]
        ]

        let catalog = try decode(articles: [article])
        let loaded = try XCTUnwrap(catalog.articles.first)
        XCTAssertEqual(loaded.officialContacts, [
            GuidanceOfficialContact(id: "office", kind: .phone, label: "代表電話", url: try XCTUnwrap(URL(string: phoneURL))),
            GuidanceOfficialContact(id: "site", kind: .web, label: "公式サイト", url: try XCTUnwrap(URL(string: webURL)))
        ])
    }

    func testDecodesAccessAndFAQArticles() throws {
        var access = standardArticleJSON(id: "access")
        access["kind"] = "access"
        access["sections"] = nil
        access["accessSegments"] = [
            ["mode": "train", "sections": [["id": "t1", "paragraphs": ["試験段落"]]]]
        ]
        var faq = standardArticleJSON(id: "faq")
        faq["kind"] = "faq"
        faq["sections"] = nil
        faq["faqItems"] = [
            ["id": "q1", "question": "試験質問", "answerParagraphs": ["試験回答"]]
        ]

        let catalog = try decode(articles: [access, faq])

        XCTAssertEqual(catalog.articles.map(\.kind), [.access, .faq])
        XCTAssertEqual(catalog.articles[0].accessSegments.map(\.mode), [.train])
        XCTAssertEqual(catalog.articles[1].faqItems.map(\.question), ["試験質問"])
    }

    func testKeepsFileOrder() throws {
        let catalog = try decode(articles: [
            standardArticleJSON(id: "b"),
            standardArticleJSON(id: "a"),
        ])
        XCTAssertEqual(catalog.articles.map(\.id.rawValue), ["b", "a"])
    }

    // MARK: - 公開条件を欠く記事（E6-6 §4）

    func testMissingSourceIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["source"] = nil
        try assertRejected(article, field: .source)
    }

    func testBlankSourceIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["source"] = "   "
        try assertRejected(article, field: .source)
    }

    func testMissingConfirmedOnIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["confirmation"] = ["confirmer": "試験確認者"]
        try assertRejected(article, field: .confirmedOn)
    }

    func testInvalidConfirmedOnIsRejected() throws {
        for invalid in ["2026-02-30", "2026/11/13", "2026-1-3", "令和8年11月13日"] {
            var article = standardArticleJSON(id: "x")
            article["confirmation"] = ["confirmedOn": invalid, "confirmer": "試験確認者"]
            try assertRejected(article, field: .confirmedOn)
        }
    }

    func testMissingConfirmerIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["confirmation"] = ["confirmedOn": "2026-11-13"]
        try assertRejected(article, field: .confirmer)
    }

    func testMissingConfirmationIsRejectedForBothFields() throws {
        var article = standardArticleJSON(id: "x")
        article["confirmation"] = nil

        let issues = try rejectionIssues(article)
        XCTAssertEqual(Set(issues.map(\.field)), [.confirmedOn, .confirmer])
    }

    func testUnknownKindIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["kind"] = "news"
        try assertRejected(article, field: .kind)
    }

    func testArticleWithoutBodyIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["sections"] = []
        try assertRejected(article, field: .body)
    }

    /// 交通手段ごとに切り替えは1つなので、同じ mode の2件目は画面から到達できない。
    func testDuplicateAccessModeIsRejected() throws {
        var article = standardArticleJSON(id: "access")
        article["kind"] = "access"
        article["sections"] = nil
        article["accessSegments"] = [
            ["mode": "train", "sections": [["id": "t1", "paragraphs": ["試験段落"]]]],
            ["mode": "train", "sections": [["id": "t2", "paragraphs": ["試験段落"]]]],
        ]
        try assertRejected(article, field: .body)
    }

    func testDuplicateSectionIDIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["sections"] = [
            ["id": "s1", "paragraphs": ["試験段落"]],
            ["id": "s1", "paragraphs": ["試験段落"]],
        ]
        try assertRejected(article, field: .body)
    }

    func testDuplicateFAQItemIDIsRejected() throws {
        var article = standardArticleJSON(id: "faq")
        article["kind"] = "faq"
        article["sections"] = nil
        article["faqItems"] = [
            ["id": "q1", "question": "試験質問", "answerParagraphs": ["試験回答"]],
            ["id": "q1", "question": "試験質問2", "answerParagraphs": ["試験回答"]],
        ]
        try assertRejected(article, field: .body)
    }

    /// 確定していない地点を空の ID で書くと無反応のボタンになるため拒否する。
    func testRelatedSpotWithoutCanonicalIDIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["relatedSpots"] = [["canonicalSpotId": "", "displayName": "試験地点"]]
        try assertRejected(article, field: .relatedSpots)
    }

    func testInvalidOfficialContactsAreRejected() throws {
        let phone = ["id": "office", "kind": "phone", "label": "代表電話", "url": "tel:0120-87-8622"]
        var article = standardArticleJSON(id: "help")
        article["officialContacts"] = [phone, phone]
        XCTAssertEqual(try rejectionIssues(article).map(\.field), [.officialContacts])

        for (field, value) in [("id", " "), ("kind", "fax"), ("label", "")] {
            var contact = phone
            contact[field] = value
            article["officialContacts"] = [contact]
            XCTAssertEqual(try rejectionIssues(article).map(\.field), [.officialContacts], field)
        }
    }

    func testInvalidOfficialContactURLsAreRejected() throws {
        var article = standardArticleJSON(id: "help")
        let invalidURLs = [
            "phone": ["", "https://www.jaa-tech.jp/", "tel:", "tel:+-()", "tel:1 2", "tel:123x", "tel:１２３"],
            "web": ["", "http://www.jaa-tech.jp/", "https:///contact"]
        ]
        for (kind, urls) in invalidURLs {
            for url in urls {
                article["officialContacts"] = [["id": "office", "kind": kind, "label": "問い合わせ", "url": url]]
                XCTAssertEqual(try rejectionIssues(article).map(\.field), [.officialContacts], "\(kind): \(url)")
            }
        }
    }

    func testDuplicateIDIsRejected() throws {
        let issues = try rejectionIssues(articles: [standardArticleJSON(id: "x"), standardArticleJSON(id: "x")])
        XCTAssertEqual(issues.map(\.field), [.id])
        XCTAssertEqual(issues.first?.articleIndex, 1)
    }

    /// 欠けた記事だけを落として残りを公開しない。1件でも欠ければ全体を読み込まない。
    func testOneInvalidArticleRejectsTheWholeFile() throws {
        var broken = standardArticleJSON(id: "broken")
        broken["source"] = nil

        let issues = try rejectionIssues(articles: [standardArticleJSON(id: "ok"), broken])
        XCTAssertEqual(issues.map(\.articleID), ["broken"])
    }

    func testUnsupportedSchemaVersionIsRejected() throws {
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "articles": []])
        XCTAssertThrowsError(try BundledGuidanceCatalog.decode(data)) { error in
            XCTAssertEqual(error as? BundledGuidanceCatalogError, .unsupportedSchemaVersion(2))
        }
    }

    func testMissingArticlesKeyIsRejected() throws {
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1])
        XCTAssertThrowsError(try BundledGuidanceCatalog.decode(data))
    }

    // MARK: - GuidanceClient と空の状態

    func testEmptyCatalogKeepsP09HeadingsAndAllTopicsInOrder() async throws {
        let store = GuidanceStore(client: .bundled(resourceURL: try writeFile(articles: [])))

        await store.loadTopIfNeeded()

        guard case .loaded(let snapshot) = store.topState else {
            return XCTFail("読み込み済みにならなかった: \(store.topState)")
        }
        XCTAssertEqual(snapshot.sections.map(\.kind.heading), ["困ったとき・緊急", "当日のご案内", "学校を知る"])
        XCTAssertEqual(snapshot.sections.map { $0.items.map(\.topic.title) }, [
            ["気分が悪くなったら", "困ったとき"],
            ["受付のご案内", "交通アクセス", "施設利用・学食", "注意事項・マナー"],
            ["学科紹介", "学校生活", "学生寮", "よくある質問（FAQ）", "このアプリについて"]
        ])
        XCTAssertEqual(snapshot.sections.flatMap(\.items).compactMap(\.articleID), [
            GuidanceArticleID(rawValue: "about")
        ])
    }

    func testAboutArticleShowsPendingGSIAttributionWithoutSchoolManuscripts() throws {
        let catalog = try decode(articles: [])
        let id = GuidanceArticleID(rawValue: "about")

        guard case .fresh(let article) = catalog.articleFetchResult(for: id) else {
            return XCTFail("このアプリについての記事が見つからなかった")
        }
        XCTAssertEqual(article.title, "このアプリについて")
        XCTAssertEqual(article.sections, [
            GuidanceSection(
                id: "gsi-attribution",
                heading: "国土地理院の測量成果",
                paragraphs: ["承認番号と正式な出典表記は確認中です。"]
            )
        ])
    }

    func testEmptyCatalogReportsArticleAsNotProvided() async throws {
        let store = GuidanceStore(client: .bundled(resourceURL: try writeFile(articles: [])))
        let id = GuidanceArticleID(rawValue: "reception")

        await store.loadArticleIfNeeded(id)

        XCTAssertEqual(store.articleState(for: id), .notProvided(id))
    }

    func testTopAssignsLegacyKindsAndStandardTopicIDsIndependentlyOfFileOrder() throws {
        var help = standardArticleJSON(id: "LegacyHelp")
        help["kind"] = "help"
        var health = standardArticleJSON(id: "LegacyHealth")
        health["kind"] = "helpHealth"
        let catalog = try decode(articles: [
            standardArticleJSON(id: "department"),
            standardArticleJSON(id: "manners"),
            help,
            standardArticleJSON(id: "facility"),
            health
        ])

        guard case .fresh(let snapshot) = catalog.topFetchResult else {
            return XCTFail("目次が見つからなかった")
        }
        XCTAssertEqual(snapshot.sections.map { $0.items.compactMap { $0.articleID?.rawValue } }, [
            ["LegacyHealth", "LegacyHelp"],
            ["facility", "manners"],
            ["department", "about"]
        ])
    }

    func testArticleLoadsFromBundledFile() async throws {
        let store = GuidanceStore(
            client: .bundled(resourceURL: try writeFile(articles: [standardArticleJSON(id: "Reception_A")]))
        )
        let id = GuidanceArticleID(rawValue: "Reception_A")

        await store.loadArticleIfNeeded(id)

        guard case .loaded(let article) = store.articleState(for: id) else {
            return XCTFail("読み込み済みにならなかった: \(store.articleState(for: id))")
        }
        XCTAssertNotNil(article.confirmation)
        // 大文字・小文字が違う ID は別の記事。
        let lower = GuidanceArticleID(rawValue: "reception_a")
        await store.loadArticleIfNeeded(lower)
        XCTAssertEqual(store.articleState(for: lower), .notProvided(lower))
    }

    func testInvalidFileFailsInsteadOfShowingArticles() async throws {
        var broken = standardArticleJSON(id: "x")
        broken["confirmation"] = nil
        let store = GuidanceStore(client: .bundled(resourceURL: try writeFile(articles: [broken])))

        await store.loadTopIfNeeded()

        guard case .failed = store.topState else {
            return XCTFail("失敗にならなかった: \(store.topState)")
        }
    }

    func testMissingResourceFails() async {
        let store = GuidanceStore(client: .bundled(resourceURL: nil))

        await store.loadTopIfNeeded()

        guard case .failed = store.topState else {
            return XCTFail("失敗にならなかった: \(store.topState)")
        }
    }

    // MARK: - Home の案内ショートカット（Home v1.0 下書き B）

    /// `homeShortcut` を持つ記事だけを、受付・困ったとき・アクセスの順に返す。
    func testHomeShortcutsFollowMarkedArticlesInFixedOrder() throws {
        var access = standardArticleJSON(id: "Access_A")
        access["homeShortcut"] = "access"
        var reception = standardArticleJSON(id: "Reception_A")
        reception["homeShortcut"] = "reception"
        var help = standardArticleJSON(id: "Help_A")
        help["homeShortcut"] = "help"
        let unmarkedReception = standardArticleJSON(id: "reception")

        let catalog = try decode(articles: [access, help, unmarkedReception, reception])

        XCTAssertEqual(catalog.homeShortcuts, [
            HomeGuidanceShortcut(shortcut: .reception, articleID: GuidanceArticleID(rawValue: "Reception_A")),
            HomeGuidanceShortcut(shortcut: .help, articleID: GuidanceArticleID(rawValue: "Help_A")),
            HomeGuidanceShortcut(shortcut: .access, articleID: GuidanceArticleID(rawValue: "Access_A")),
        ])
        guard case .fresh(let snapshot) = catalog.topFetchResult else {
            return XCTFail("目次が見つからなかった")
        }
        let items = snapshot.sections.flatMap(\.items)
        for shortcut in catalog.homeShortcuts {
            let topic = GuidanceMenuTopic(rawValue: shortcut.shortcut.rawValue)
            XCTAssertEqual(items.first { $0.topic == topic }?.articleID, shortcut.articleID)
            guard case .fresh(let article) = catalog.articleFetchResult(for: shortcut.articleID) else {
                return XCTFail("Home のショートカットの遷移先が見つからなかった")
            }
            XCTAssertEqual(article.id, shortcut.articleID)
        }
    }

    /// 印を付けた記事がなければショートカットは0件。
    func testHomeShortcutsAreEmptyWithoutMarkedArticles() throws {
        XCTAssertEqual(try decode(articles: [standardArticleJSON(id: "Plain_A")]).homeShortcuts, [])
        XCTAssertEqual(try decode(articles: []).homeShortcuts, [])
    }

    func testUnknownHomeShortcutIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["homeShortcut"] = "faq"
        XCTAssertEqual(try rejectionIssues(article).map(\.field), [.homeShortcut])
    }

    /// 同じショートカットを2つの記事に付けると、どちらを開くか決まらないため拒否する。
    func testDuplicateHomeShortcutIsRejected() throws {
        var first = standardArticleJSON(id: "a")
        first["homeShortcut"] = "help"
        var second = standardArticleJSON(id: "b")
        second["homeShortcut"] = "help"

        let issues = try rejectionIssues(articles: [first, second])
        XCTAssertEqual(issues.map(\.field), [.homeShortcut])
        XCTAssertEqual(issues.first?.articleIndex, 1)
    }

    /// Home は同梱ファイルを読めないとき、ショートカットを出さない（失敗は案内タブが示す）。
    func testHomeShortcutLoaderReturnsNothingForMissingOrInvalidFile() async throws {
        let missing = await HomeClient.bundledGuidanceShortcuts(resourceURL: nil)()
        XCTAssertEqual(missing, [])

        var broken = standardArticleJSON(id: "broken")
        broken["source"] = nil
        broken["homeShortcut"] = "reception"
        let invalid = await HomeClient.bundledGuidanceShortcuts(resourceURL: try writeFile(articles: [broken]))()
        XCTAssertEqual(invalid, [])

        var reception = standardArticleJSON(id: "Reception_A")
        reception["homeShortcut"] = "reception"
        let valid = await HomeClient.bundledGuidanceShortcuts(resourceURL: try writeFile(articles: [reception]))()
        XCTAssertEqual(valid.map(\.shortcut), [.reception])
    }

    // MARK: - 補助

    private func standardArticleJSON(id: String) -> [String: Any] {
        [
            "id": id,
            "kind": "standard",
            "navigationTitle": "試験表題",
            "title": "試験見出し語",
            "sections": [
                ["id": "s1", "heading": "試験見出し", "paragraphs": ["試験段落"]]
            ],
            "relatedSpots": [
                ["canonicalSpotId": "test_spot_001", "displayName": "試験地点"]
            ],
            "source": "試験資料 2026-11-01",
            "confirmation": ["confirmedOn": "2026-11-13", "confirmer": "試験確認者"],
        ]
    }

    private func fileData(articles: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "articles": articles])
    }

    private func decode(articles: [[String: Any]]) throws -> BundledGuidanceCatalog {
        try BundledGuidanceCatalog.decode(fileData(articles: articles))
    }

    private func writeFile(articles: [[String: Any]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuidanceArticles-\(UUID().uuidString).json")
        try fileData(articles: articles).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func rejectionIssues(_ article: [String: Any]) throws -> [GuidanceArticleIssue] {
        try rejectionIssues(articles: [article])
    }

    private func rejectionIssues(articles: [[String: Any]]) throws -> [GuidanceArticleIssue] {
        do {
            _ = try decode(articles: articles)
        } catch BundledGuidanceCatalogError.invalidArticles(let issues) {
            return issues
        }
        XCTFail("公開条件を欠く記事が読み込まれた")
        return []
    }

    private func assertRejected(
        _ article: [String: Any],
        field: GuidanceArticleIssue.Field,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let issues = try rejectionIssues(article)
        XCTAssertTrue(
            issues.contains { $0.field == field },
            "\(field) の不備として報告されなかった: \(issues)",
            file: file,
            line: line
        )
    }
}
