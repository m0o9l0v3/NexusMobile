import XCTest
@testable import Nexus

final class CanonicalSpotIDTests: XCTestCase {
    func testRawValuePreservesCaseAndCharacters() {
        let identifier = CanonicalSpotID(rawValue: "Mb_1F_RM_001")

        XCTAssertEqual(identifier.rawValue, "Mb_1F_RM_001")
    }

    func testComparisonIsCaseSensitive() {
        let uppercase = CanonicalSpotID(rawValue: "SPOT_A")
        let lowercase = CanonicalSpotID(rawValue: "spot_a")

        XCTAssertNotEqual(uppercase, lowercase)
    }

    // MARK: - 今回追加

    func testCodableRoundTripPreservesCase() throws {
        let original = CanonicalSpotID(rawValue: "Mb_2F_CL_001")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CanonicalSpotID.self, from: data)

        XCTAssertEqual(decoded.rawValue, "Mb_2F_CL_001")
        XCTAssertEqual(decoded, original)
    }

    func testSpotSummaryUsesSuppliedIdentifierNotDisplayName() {
        let summary = SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
            displayName: "2A教室",
            kind: .classroom,
            buildingName: "教室棟",
            floorName: "2F"
        )

        XCTAssertEqual(summary.canonicalSpotID.rawValue, "mb_2f_cl_001")
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

    /// bundle の `kind` が null・未知の値のときは種別を表示しない（E2-5 O-2c）。既存の種別へ置き換えない。
    func testSpotSummaryWithoutKindOmitsKind() {
        let summary = SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: "mb"),
            displayName: "教室棟",
            kind: nil,
            buildingName: "教室棟"
        )

        XCTAssertEqual(summary.supplementaryText, "教室棟")
        XCTAssertEqual(summary.accessibilityLabelText, "教室棟、教室棟")
    }

    func testSpotSummaryWithoutKindOrLocationHasNoSupplementaryText() {
        let summary = SpotSummary(
            canonicalSpotID: CanonicalSpotID(rawValue: "campus_lm_001"),
            displayName: "航空神社",
            kind: nil
        )

        XCTAssertEqual(summary.supplementaryText, "")
        XCTAssertEqual(summary.accessibilityLabelText, "航空神社、場所は未提供")
    }

    /// 展示は地点の種別に含めない（E2-5 O-2b）。
    func testSpotKindMatchesBundleCandidates() {
        XCTAssertEqual(SpotKind.allCases.map(\.rawValue), ["classroom", "facility", "service"])
        XCTAssertNil(SpotKind(rawValue: "exhibit"))
    }
}
