import XCTest
@testable import Nexus

/// 同梱の案内原稿（E6-6 案A、#86）の復号・公開条件の検証・空の状態。
///
/// 本文・地点名などは**試験専用の値**で、正式な原稿ではない（原稿の担い手 U-1 は未決）。
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

    /// 原稿の担い手（E6-6 §5 U-1）が決まるまでは、記事を1件も同梱しない。
    /// U-1 が決まり、正式原稿を入れる PR でこの試験を外す。
    func testShippedGuidanceFileHasNoArticlesUntilContentOwnerIsDecided() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: BundledGuidanceCatalog.resourceName,
                withExtension: BundledGuidanceCatalog.resourceExtension
            )
        )
        let catalog = try BundledGuidanceCatalog.decode(Data(contentsOf: url))
        XCTAssertEqual(catalog.articles, [], "U-1 決定前に原稿が入っている")
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
        let confirmation = try XCTUnwrap(article.confirmation)
        XCTAssertEqual(confirmation.source, "試験資料 2026-11-01")
        XCTAssertEqual(confirmation.confirmer, "試験確認者")
        XCTAssertEqual(confirmation.confirmedOn.displayText, "2026年11月13日")
        XCTAssertEqual(confirmation.statusText, "確認日：2026年11月13日")
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

    /// 確定していない地点を空の ID で書くと無反応のボタンになるため拒否する。
    func testRelatedSpotWithoutCanonicalIDIsRejected() throws {
        var article = standardArticleJSON(id: "x")
        article["relatedSpots"] = [["canonicalSpotId": "", "displayName": "試験地点"]]
        try assertRejected(article, field: .relatedSpots)
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

    func testEmptyCatalogShowsEmptyStateOnTop() async throws {
        let store = GuidanceStore(client: .bundled(resourceURL: try writeFile(articles: [])))

        await store.loadTopIfNeeded()

        XCTAssertEqual(store.topState, .empty(BundledGuidanceCatalog.emptyMessage))
    }

    func testEmptyCatalogReportsArticleAsNotProvided() async throws {
        let store = GuidanceStore(client: .bundled(resourceURL: try writeFile(articles: [])))
        let id = GuidanceArticleID(rawValue: "reception")

        await store.loadArticleIfNeeded(id)

        XCTAssertEqual(store.articleState(for: id), .notProvided(id))
    }

    func testTopPutsHelpArticlesInTroubleList() async throws {
        var help = standardArticleJSON(id: "help")
        help["kind"] = "help"
        let store = GuidanceStore(
            client: .bundled(resourceURL: try writeFile(articles: [standardArticleJSON(id: "std"), help]))
        )

        await store.loadTopIfNeeded()

        guard case .loaded(let snapshot) = store.topState else {
            return XCTFail("読み込み済みにならなかった: \(store.topState)")
        }
        XCTAssertEqual(snapshot.troubleItems.map(\.id.rawValue), ["help"])
        XCTAssertEqual(snapshot.sections.flatMap(\.items).map(\.id.rawValue), ["std"])
        // 内蔵の原稿に「オフライン保存版」などの更新状況は出さない（E6-6 §3）。
        XCTAssertNil(snapshot.updateStatus)
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
