import XCTest
@testable import Nexus

/// JSON Schema の正常例（`docs/schemas/examples/participant-bundle-v2.example.json`）を iOS の検証に通す。
///
/// Schema 側の試験（`tools/map-dataset`）は同じファイルが Schema に適合することを確かめる。
/// 両方が同じファイルを使うことで、Studio の射影が満たす Schema と iOS の受信時の検査の食い違いを見つける。
final class ParticipantBundleSchemaExampleTests: XCTestCase {

    private static let exampleURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // PublishedBundle
        .deletingLastPathComponent() // NexusTests
        .deletingLastPathComponent() // nexus-ios
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // リポジトリのルート
        .appendingPathComponent("docs/schemas/examples/participant-bundle-v2.example.json")

    func testSchemaExamplePassesValidator() throws {
        let body = try Data(contentsOf: Self.exampleURL)
        let headers = ParticipantBundleHeaders(
            sha256: ParticipantBundleValidator.sha256Hex(of: body),
            byteLength: body.count,
            bundleVersion: 42,
            schemaVersion: "2.0.0",
            etag: "\"sha256-example\""
        )

        let bundle = try ParticipantBundleValidator.validate(body: body, headers: headers)

        XCTAssertEqual(bundle.spots.map(\.id), ["campus_lm_001", "mb", "mb_1f_cl_001", "mb_ent_001"])
        let byID = Dictionary(uniqueKeysWithValues: bundle.spots.map { ($0.id, $0) })
        XCTAssertNil(byID["mb"]?.kind)
        XCTAssertEqual(byID["mb_1f_cl_001"]?.placement?.floorID, "mb_1f")
        XCTAssertEqual(byID["mb_1f_cl_001"]?.placement?.accessNodeID, "mb_1f_n_005")
        XCTAssertNil(byID["mb_ent_001"]?.placement?.accessNodeID)
        XCTAssertNil(byID["campus_lm_001"]?.placement?.buildingID)
        XCTAssertEqual(bundle.map?.geojson.schemaVersion, "2.0.0")
    }
}
