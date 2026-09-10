import XCTest
@testable import Nexus

final class AppRouteRequestTests: XCTestCase {
    func testRouteRequestKeepsCanonicalIdentifierVerbatim() {
        let identifier = CanonicalSpotID(rawValue: "Mb_F1_EET_1")
        let request = AppRouteRequest.route(destinationSpotID: identifier)

        guard case .route(let destination) = request else {
            return XCTFail("Expected a route request")
        }

        XCTAssertEqual(destination.rawValue, "Mb_F1_EET_1")
    }

    // MARK: - 今回追加

    func testEmptySearchRequestDefaultsToBrowseIntent() {
        // `intent` に既定値を足しても既存の初期化呼び出しと `.empty` が壊れないことを固定する。
        XCTAssertEqual(HomeSearchRequest.empty, HomeSearchRequest(query: nil, categoryID: nil))
        XCTAssertEqual(HomeSearchRequest.empty.intent, .browse)
        XCTAssertFalse(HomeSearchRequest.empty.intent.focusesInput)
        XCTAssertFalse(HomeSearchRequest.empty.intent.clearsPreviousConditions)
    }

    func testSearchRequestCarriesFocusIntent() {
        let request = HomeSearchRequest.focusedNewSearch

        XCTAssertTrue(request.intent.focusesInput)
        XCTAssertTrue(request.intent.clearsPreviousConditions)
        XCTAssertNil(request.query)
        XCTAssertNil(request.categoryID)
    }

    func testSpotDetailsRequestKeepsCanonicalIdentifierVerbatim() {
        let request = AppRouteRequest.spotDetails(
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")
        )

        guard case .spotDetails(let canonicalSpotID) = request else {
            return XCTFail("Expected a spotDetails request")
        }
        XCTAssertEqual(canonicalSpotID.rawValue, "mb_f2_cr_2a")
    }

    func testEventDetailsRequestKeepsBothIdentifiers() {
        let request = AppRouteRequest.eventDetails(
            eventID: "PREVIEW_EVENT_DRONE",
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a")
        )

        guard case .eventDetails(let eventID, let canonicalSpotID) = request else {
            return XCTFail("Expected an eventDetails request")
        }
        XCTAssertEqual(eventID, "PREVIEW_EVENT_DRONE")
        XCTAssertEqual(canonicalSpotID.rawValue, "mb_f2_cr_2a")
    }

    func testGuidanceArticleRequestKeepsArticleIdentifierVerbatim() {
        let request = AppRouteRequest.guidanceArticle(
            articleID: GuidanceArticleID(rawValue: "PREVIEW_GUIDE_RECEPTION")
        )

        guard case .guidanceArticle(let articleID) = request else {
            return XCTFail("Expected a guidanceArticle request")
        }
        XCTAssertEqual(articleID.rawValue, "PREVIEW_GUIDE_RECEPTION")
    }
}
