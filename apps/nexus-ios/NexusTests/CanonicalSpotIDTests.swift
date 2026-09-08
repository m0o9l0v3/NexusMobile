import XCTest
@testable import Nexus

final class CanonicalSpotIDTests: XCTestCase {
    func testRawValuePreservesCaseAndCharacters() {
        let identifier = CanonicalSpotID(rawValue: "Mb_F1_EET_1")

        XCTAssertEqual(identifier.rawValue, "Mb_F1_EET_1")
    }

    func testComparisonIsCaseSensitive() {
        let uppercase = CanonicalSpotID(rawValue: "SPOT_A")
        let lowercase = CanonicalSpotID(rawValue: "spot_a")

        XCTAssertNotEqual(uppercase, lowercase)
    }
}
