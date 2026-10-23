import XCTest
@testable import Nexus

/// bundle の外から来た ID の解決（E2-5 §6 規則11、#109 の受入条件）。
final class ExternalSpotIDResolverTests: XCTestCase {

    /// 検証済みの bundle。`mb_2f_classroom_a` は `mb_2f_cl_001` への alias（形式の例）。
    private func validatedResolver() throws -> ExternalSpotIDResolver {
        let object = BundleFixtures.bundleObject(
            idAliases: [["alias": "mb_2f_classroom_a", "canonical_id": "mb_2f_cl_001"]]
        )
        let response = BundleFixtures.response(object)
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        return ExternalSpotIDResolver(bundle: bundle)
    }

    /// 不変条件の検査を通さずにデコードした bundle。解決器が検査済みであることに頼らないかを試す。
    private func unvalidatedResolver(idAliases: [[String: Any]]) throws -> ExternalSpotIDResolver {
        let data = BundleFixtures.data(BundleFixtures.bundleObject(idAliases: idAliases))
        return ExternalSpotIDResolver(bundle: try JSONDecoder().decode(ParticipantBundle.self, from: data))
    }

    func testExactMatchResolvesToItself() throws {
        XCTAssertEqual(try validatedResolver().resolve("mb_2f_cl_001"), .resolved(CanonicalSpotID(rawValue: "mb_2f_cl_001")))
    }

    func testAliasResolvesOneStepToCanonicalID() throws {
        XCTAssertEqual(
            try validatedResolver().resolve("mb_2f_classroom_a"),
            .resolved(CanonicalSpotID(rawValue: "mb_2f_cl_001"))
        )
    }

    func testUnknownIDIsNotListed() throws {
        XCTAssertEqual(try validatedResolver().resolve("mb_9f_cl_001"), .notListed)
        XCTAssertEqual(try validatedResolver().resolve(""), .notListed)
    }

    func testCaseDifferenceIsNotListed() throws {
        let resolver = try validatedResolver()

        XCTAssertEqual(resolver.resolve("MB_2F_CL_001"), .notListed)
        XCTAssertEqual(resolver.resolve("Mb_2F_Classroom_A"), .notListed)
    }

    /// 資料上の旧 ID（E1-7 の対応表）は台帳に登録しないため、未掲載になる（O-3a）。
    func testDocumentLegacyIDIsNotListed() throws {
        XCTAssertEqual(try validatedResolver().resolve("mb_f2_cr_2a"), .notListed)
    }

    /// alias は1段だけ。解決先が別の alias でも、それを辿らない。
    func testAliasChainIsNotFollowed() throws {
        let resolver = try unvalidatedResolver(idAliases: [
            ["alias": "old_b", "canonical_id": "mb_2f_cl_001"],
            ["alias": "old_a", "canonical_id": "old_b"],
        ])

        XCTAssertEqual(resolver.resolve("old_b"), .resolved(CanonicalSpotID(rawValue: "mb_2f_cl_001")))
        XCTAssertEqual(resolver.resolve("old_a"), .notListed)
    }

    /// 解決先がこの版の spots に無い alias は未掲載にする。別の地点へ置き換えない。
    func testAliasToMissingSpotIsNotListed() throws {
        let resolver = try unvalidatedResolver(idAliases: [["alias": "old_room", "canonical_id": "mb_9f_cl_001"]])

        XCTAssertEqual(resolver.resolve("old_room"), .notListed)
    }

    func testCanonicalSpotIDOverloadUsesRawValueAsIs() throws {
        let resolver = try validatedResolver()

        XCTAssertEqual(
            resolver.resolve(CanonicalSpotID(rawValue: "mb_2f_classroom_a")),
            .resolved(CanonicalSpotID(rawValue: "mb_2f_cl_001"))
        )
        XCTAssertEqual(resolver.resolve(CanonicalSpotID(rawValue: "Mb_2F_CL_001")), .notListed)
    }
}
