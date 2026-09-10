import XCTest
@testable import Nexus

@MainActor
final class AppRouterTests: XCTestCase {
    func testTabActivationPreservesEveryStackPath() {
        let router = AppRouter()
        router.push(.notProvided(.announcementList), on: .home)
        router.push(.notProvided(.eventList), on: .map)
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "A")), on: .guide)
        router.push(.notProvided(.announcementDetail), on: .search)

        router.activate(.map)
        router.activate(.map)
        router.activate(.guide)

        XCTAssertEqual(router.homePath, [.notProvided(.announcementList)])
        XCTAssertEqual(router.mapPath, [.notProvided(.eventList)])
        XCTAssertEqual(router.guidePath, [.guidanceArticle(GuidanceArticleID(rawValue: "A"))])
        XCTAssertEqual(router.searchPath, [.notProvided(.announcementDetail)])
    }

    func testSelectedTabChangeDoesNotMutatePaths() {
        let router = AppRouter()
        for tab in AppTab.allCases {
            router.activate(tab)
        }
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.mapPath.isEmpty)
        XCTAssertTrue(router.guidePath.isEmpty)
        XCTAssertTrue(router.searchPath.isEmpty)
    }

    func testPushAppliesToRequestedTabOnly() {
        let router = AppRouter()
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "reception")), on: .guide)

        XCTAssertEqual(router.guidePath.count, 1)
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertTrue(router.mapPath.isEmpty)
        XCTAssertTrue(router.searchPath.isEmpty)
    }

    func testPopToRootDoesNotAffectOtherTabs() {
        let router = AppRouter()
        router.push(.notProvided(.eventList), on: .home)
        router.push(.guidanceArticle(GuidanceArticleID(rawValue: "A")), on: .guide)

        router.popToRoot(of: .home)

        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertEqual(router.guidePath.count, 1)
    }
}
