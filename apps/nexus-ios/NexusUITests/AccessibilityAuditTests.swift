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
        try audit(app, when: classroom)
    }

    func testGuidance() throws {
        let app = launch(["-NexusPreviewScreen", "guidance"])
        try audit(app, when: app.buttons["当日の流れ"])
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

    private func audit(_ app: XCUIApplication, when element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("監査対象の画面が表示されませんでした: \(element)", file: file, line: line)
            return
        }
        try app.performAccessibilityAudit(for: [
            .contrast, .elementDetection, .hitRegion, .sufficientElementDescription,
            .dynamicType, .textClipped, .trait
        ])
    }
}
