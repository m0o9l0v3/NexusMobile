import XCTest

@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testHome() throws {
        let app = launch()
        let dayCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "オープンキャンパス開催日")).firstMatch
        try audit(app, when: dayCard) { issue in
            if Self.acceptsSecondaryLabel(issue, labels: [
                "今日はどこへ行きますか？", "教室・施設・サービスを検索", "オープンキャンパス開催日",
                "15:00まで公開中です", "検討用", "2A教室",
            ]) { return true }
            // 案内ショートカットの記号は読み上げない飾り。細い線の記号だけ、縁の中間色で失敗と判定される
            // （記号を消すと指摘が消える）。記号の AccentColor は Surface の上で本文の 4.5:1 を満たす
            // （`AccessibilityContrastTests.testAccentTextMeetsAA`）。
            if issue.auditType == .contrast, let label = issue.element?.label, ["困ったとき", "アクセス"].contains(label) {
                XCTContext.runActivity(named: "飾りの記号の縁「\(label)」") { _ in }
                return true
            }
            // 「この後のイベント」のカードは1枚ごとに1つの読み上げ要素で、中の文字の指摘は要素を特定できない（element が nil）。
            // 起動直後はカードの下半分がタブバーの下にあり、タブバー越しの色で失敗と判定される（下の audit の許容と同じ理由）。
            // カードの文字色は単体試験（secondaryLabel・AccentColor の cardSurface 上）で確かめる。
            if issue.element == nil, issue.auditType == .contrast {
                XCTContext.runActivity(named: "要素を特定できない文字（タブバーの下のカード）") { _ in }
                return true
            }
            return false
        }
    }

    func testSearch() throws {
        let app = launch(["-NexusPreviewScreen", "search"])
        let classroom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2A教室")).firstMatch
        try audit(app, when: classroom) { issue in
            Self.acceptsSecondaryLabel(issue, labels: ["3件", "教室棟・2F", "構内"])
        }
    }

    func testGuidance() throws {
        let app = launch(["-NexusPreviewScreen", "guidance"])
        try audit(app, when: app.buttons["受付のご案内"])
    }

    func testBundledGuidanceOpensHealthAndAttribution() {
        let app = XCUIApplication()
        app.launchArguments = ["-NexusPreviewScreen", "guidance"]
        app.launch()

        let emergency = app.staticTexts["困ったとき・緊急"]
        XCTAssertTrue(emergency.waitForExistence(timeout: 10))
        let pending = NSPredicate(format: "label CONTAINS %@", "準備中")
        XCTAssertFalse(app.descendants(matching: .any).matching(pending).firstMatch.exists)

        let health = app.buttons["気分が悪くなったら"]
        XCTAssertTrue(health.exists)
        health.tap()
        let article = app.scrollViews.firstMatch
        XCTAssertTrue(article.staticTexts["体調が悪いときは、その場で助けを呼んでください"].waitForExistence(timeout: 10))
        // 119番は本文の案内。この記事から開ける連絡先は FAQ のみ。
        XCTAssertEqual(article.buttons.allElementsBoundByIndex.map(\.label), ["よくあるご質問"])
        XCTAssertFalse(article.links.firstMatch.exists)
        for text in ["確認日：", "2026-11-25", "リポジトリオーナー", "日本航空大学校公式サイト"] {
            XCTAssertFalse(article.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists, text)
        }
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(emergency.waitForExistence(timeout: 10))

        let about = app.buttons["このアプリについて"]
        for _ in 0..<8 where !about.isHittable { app.swipeUp() }
        XCTAssertTrue(about.isHittable)
        about.tap()

        XCTAssertTrue(app.staticTexts["国土地理院の測量成果"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["この地図の作成に当たっては、国土地理院の基盤地図情報（建築物の外周線・道路縁）を使用しました。"].exists)
        XCTAssertTrue(app.staticTexts["プライバシー"].exists)
        XCTAssertFalse(app.staticTexts["承認番号と正式な出典表記は確認中です。"].exists)
    }

    func testGuidanceArticleHidesConfirmationMetadata() {
        let app = launch(["-NexusPreviewScreen", "guidanceStandard"])

        XCTAssertTrue(app.staticTexts["受付案内"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["受付場所"].exists)
        for text in ["確認日：", "プレビュー用の確認者", "プレビュー用の出典"] {
            let predicate = NSPredicate(format: "label CONTAINS %@", text)
            XCTAssertFalse(app.staticTexts.containing(predicate).firstMatch.exists, text)
        }
    }

    func testGuidanceRestoresTabBarAfterBackSwipe() {
        let app = launch(["-NexusPreviewScreen", "guidance"])
        let reception = app.buttons["受付のご案内"]
        XCTAssertTrue(reception.waitForExistence(timeout: 10))
        reception.tap()
        XCTAssertTrue(app.staticTexts["受付案内"].waitForExistence(timeout: 10))

        let homeTab = app.tabBars.buttons["ホーム"]
        XCTAssertFalse(homeTab.isHittable)

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: 1, dy: 0))
        let farSide = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: farSide)

        XCTAssertTrue(reception.waitForExistence(timeout: 10))
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
    }

    /// 記事の「場所を見る」でマップへ移り、案内へ戻って目次へ戻ったあとも、タブを切り替えられる。
    func testGuidanceTabBarWorksAfterOpeningRelatedPlace() {
        let app = launch(["-NexusPreviewScreen", "guidance"])
        let facilities = app.buttons["施設利用・学食"]
        XCTAssertTrue(facilities.waitForExistence(timeout: 10))
        facilities.tap()

        let showPlace = app.buttons["場所を見る"]
        XCTAssertTrue(showPlace.waitForExistence(timeout: 10))
        let tabBar = app.tabBars.firstMatch
        XCTAssertFalse(tabBar.buttons["ホーム"].isHittable)
        showPlace.tap()

        let guideTab = tabBar.buttons["案内"]
        XCTAssertTrue(guideTab.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["マップ"].isSelected)
        guideTab.tap()
        XCTAssertTrue(showPlace.waitForExistence(timeout: 5))
        XCTAssertFalse(tabBar.buttons["ホーム"].isHittable)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(facilities.waitForExistence(timeout: 10))
        let homeTab = tabBar.buttons["ホーム"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected)
    }

    func testUnpublishedMap() throws {
        let app = launch(["-NexusPreviewScreen", "map", "-NexusMapState", "notPublished", "-NexusLocationFixture", "denied"])
        try audit(app, when: app.staticTexts["構内地図はまだ公開されていません"]) { issue in
            Self.acceptsSecondaryLabel(issue, labels: ["公開されると、建物・階と地点をここに表示します。"])
        }
    }

    /// M1 v1.0 の F-1 で継続使用が決まった secondaryLabel の補足だけを許容する。
    /// 画面ごとに文言を列挙し、新しく増えた補足や別の種類の指摘は失敗のままにする。
    private static func acceptsSecondaryLabel(_ issue: XCUIAccessibilityAuditIssue, labels: Set<String>) -> Bool {
        guard issue.auditType == .contrast,
              let label = issue.element?.label,
              labels.contains(label) else { return false }
        XCTContext.runActivity(named: "F-1 の補足テキスト「\(label)」") { _ in }
        return true
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-NexusPreviewData"] + arguments
        app.launch()
        return app
    }

    private func audit(
        _ app: XCUIApplication,
        when element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line,
        acceptsIssue: ((XCUIAccessibilityAuditIssue) -> Bool)? = nil
    ) throws {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("監査対象の画面が表示されませんでした: \(element)", file: file, line: line)
            return
        }
        let tabBar = app.tabBars.firstMatch
        let tabBarFrame = tabBar.exists ? tabBar.frame : nil
        try app.performAccessibilityAudit(for: [
            .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
            .dynamicType, .textClipped, .trait
        ]) { issue in
            // 半透明のタブバーの下に入った行は、タブバー越しの色で失敗と判定される。スクロールすれば読めるため許容する。
            if issue.auditType == .contrast, let tabBarFrame, let frame = issue.element?.frame,
               frame.intersects(tabBarFrame) {
                XCTContext.runActivity(named: "タブバーの下の要素「\(issue.element?.label ?? "")」") { _ in }
                return true
            }
            return acceptsIssue?(issue) ?? false
        }
    }
}
