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

    // MARK: - 今回追加

    func testCodableRoundTripPreservesCase() throws {
        let original = CanonicalSpotID(rawValue: "Mb_F2_CR_2A")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CanonicalSpotID.self, from: data)

        XCTAssertEqual(decoded.rawValue, "Mb_F2_CR_2A")
        XCTAssertEqual(decoded, original)
    }

    func testSpotSummaryUsesSuppliedIdentifierNotDisplayName() {
        let summary = SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
            displayName: "2A教室",
            kind: .classroom,
            buildingName: "教室棟",
            floorName: "2F"
        )

        XCTAssertEqual(summary.canonicalSpotID.rawValue, "mb_f2_cr_2a")
        XCTAssertEqual(summary.supplementaryText, "教室棟・2F".isEmpty ? "教室" : "教室・教室棟・2F")
        XCTAssertEqual(summary.accessibilityLabelText, "2A教室、教室、教室棟、2F")
    }

    func testSpotSummaryWithoutLocationSaysNotProvided() {
        let summary = SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: "unknown_location"),
            displayName: "場所未確定の地点",
            kind: .service
        )

        XCTAssertEqual(summary.locationText, "")
        XCTAssertEqual(summary.supplementaryText, "サービス")
        XCTAssertEqual(summary.accessibilityLabelText, "場所未確定の地点、サービス、場所は未提供")
    }
}
