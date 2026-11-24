import XCTest

@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testHome() throws {
        let app = launch()
        let dayCard = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "オープンキャンパス開催日")).firstMatch
        try audit(app, when: dayCard)
    }

    func testSearch() throws {
        let app = launch(["-NexusPreviewScreen", "search"])
        let classroom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2A教室")).firstMatch
        try audit(app, when: classroom) { issue in
            // M1 v1.0 の F-1 で継続使用が決まった secondaryLabel の補足だけを許容する。
            guard issue.auditType == .contrast,
                  let label = issue.element?.label,
                  ["3件", "教室棟・2F", "構内"].contains(label) else { return false }
            XCTContext.runActivity(named: "F-1 の補足テキスト「\(label)」") { _ in }
            return true
        }
    }

    func testGuidance() throws {
        let app = launch(["-NexusPreviewScreen", "guidance"])
        try audit(app, when: app.buttons["受付のご案内"])
    }

    func testGuidanceShowsPendingTopicsAndOpensAttribution() {
        let app = XCUIApplication()
        app.launchArguments = ["-NexusPreviewScreen", "guidance"]
        app.launch()

        let emergency = app.staticTexts["困ったとき・緊急"]
        XCTAssertTrue(emergency.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["気分が悪くなったら"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "準備中")).firstMatch.exists)

        let about = app.buttons["このアプリについて"]
        if !about.isHittable { app.swipeUp() }
        XCTAssertTrue(about.isHittable)
        about.tap()

        XCTAssertTrue(app.staticTexts["国土地理院の測量成果"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["承認番号と正式な出典表記は確認中です。"].exists)
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

    func testUnpublishedMap() throws {
        let app = launch(["-NexusPreviewScreen", "map", "-NexusMapState", "notPublished", "-NexusLocationFixture", "denied"])
        try audit(app, when: app.staticTexts["構内地図はまだ公開されていません"])
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
        try app.performAccessibilityAudit(for: [
            .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
            .dynamicType, .textClipped, .trait
        ], acceptsIssue)
    }
}
