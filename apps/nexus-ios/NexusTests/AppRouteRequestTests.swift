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
}
