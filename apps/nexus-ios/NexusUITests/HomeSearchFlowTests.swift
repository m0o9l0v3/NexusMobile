import XCTest

@MainActor
final class HomeSearchFlowTests: XCTestCase {
    func testHomeInlineSearchReturnsFromMapAndClosesOnRetap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-NexusPreviewData", "-NexusLocationFixture", "denied"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        let homeTab = tabBar.buttons["ホーム"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        XCTAssertEqual(tabBar.buttons.count, 3)

        let entry = app.buttons["教室・施設・サービスを検索"]
        let field = app.textFields["検索語の入力"]
        let cancel = app.buttons["キャンセル"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))

        field.typeText("2A")
        let classroom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2A教室")).firstMatch
        let otherSpot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "格納庫A")).firstMatch
        XCTAssertTrue(classroom.waitForExistence(timeout: 10))
        XCTAssertTrue(otherSpot.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["検索語を消去"].exists)
        let category = app.buttons["教室"]
        category.tap()
        classroom.tap()
        XCTAssertTrue(app.buttons["地点詳細を閉じる"].waitForExistence(timeout: 10))

        homeTab.tap()
        XCTAssertTrue(classroom.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "2A")
        XCTAssertTrue(category.isSelected)
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        homeTab.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertFalse(field.exists)

        entry.tap()
        XCTAssertTrue(app.buttons["履歴を消去"].waitForExistence(timeout: 10))
        app.buttons["履歴を消去"].tap()
        XCTAssertTrue(otherSpot.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
    }
}
