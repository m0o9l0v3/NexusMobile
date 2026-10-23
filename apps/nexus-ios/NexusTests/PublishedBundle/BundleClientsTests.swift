import XCTest
@testable import Nexus

/// 保存済みの bundle から作る `MapContentClient`・`SearchClient`（#109 の進め方2）。
final class BundleClientsTests: XCTestCase {

    private let confirmedAt = Date(timeIntervalSince1970: 1_793_523_900) // 2026-11-01 18:05 JST

    private func snapshot(
        spots: [[String: Any]]? = nil,
        isConfirmedLatest: Bool = true,
        lastConfirmedAt: Date? = nil
    ) throws -> PublishedBundleSnapshot {
        let response = BundleFixtures.response(BundleFixtures.bundleObject(spots: spots))
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        let metadata = StoredBundleMetadata(
            bundleVersion: bundle.meta.bundleVersion,
            releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion,
            sha256: response.headers.sha256,
            byteLength: response.headers.byteLength,
            publishedAt: bundle.meta.publishedAt,
            etag: response.headers.etag,
            storedAt: confirmedAt
        )
        return PublishedBundleSnapshot(
            stored: StoredParticipantBundle(bundle: bundle, metadata: metadata),
            isConfirmedLatest: isConfirmedLatest,
            lastConfirmedAt: lastConfirmedAt ?? (isConfirmedLatest ? confirmedAt : nil)
        )
    }

    private func mapClient(_ snapshot: PublishedBundleSnapshot?) -> MapContentClient {
        .bundle(source: .fixed(snapshot))
    }

    private func searchClient(_ snapshot: PublishedBundleSnapshot?) -> SearchClient {
        .bundle(source: .fixed(snapshot))
    }

    // MARK: - MapContentClient

    func testSpotDetailUsesBundleNamesAndPlacement() async throws {
        let result = try await mapClient(snapshot()).spotDetail(CanonicalSpotID(rawValue: "mb_2f_cl_001"))

        guard case .fresh(let presentation) = result else {
            return XCTFail("最新の地点詳細にならなかった: \(result)")
        }
        XCTAssertEqual(presentation.summary.displayName, "2A教室")
        XCTAssertEqual(presentation.summary.kind, .classroom)
        // 建物名・階名は map.geojson の building.properties.name と nexus.floors[].name から得る。
        XCTAssertEqual(presentation.summary.buildingName, "教室棟")
        XCTAssertEqual(presentation.summary.floorName, "2F")
        XCTAssertNil(presentation.descriptionText)
    }

    func testBuildingSpotDoesNotRepeatItsOwnBuildingName() async throws {
        let result = try await mapClient(snapshot()).spotDetail(CanonicalSpotID(rawValue: "mb"))

        guard case .fresh(let presentation) = result else {
            return XCTFail("最新の地点詳細にならなかった: \(result)")
        }
        XCTAssertEqual(presentation.summary.displayName, "教室棟")
        XCTAssertNil(presentation.summary.kind)
        XCTAssertNil(presentation.summary.buildingName)
    }

    func testUnknownOrCaseDifferentIDIsUnknownSpot() async throws {
        let client = mapClient(try snapshot())

        for raw in ["mb_9f_cl_001", "MB_2F_CL_001", "mb_f2_cr_2a"] {
            let id = CanonicalSpotID(rawValue: raw)
            let result = try await client.spotDetail(id)
            XCTAssertEqual(result, .unknownSpot(id), raw)
        }
    }

    func testUnknownKindIsShownWithoutKind() async throws {
        var spots = BundleFixtures.validSpots()
        spots[0]["kind"] = "restroom"
        let result = try await mapClient(snapshot(spots: spots)).spotDetail(CanonicalSpotID(rawValue: "mb_2f_cl_001"))

        guard case .fresh(let presentation) = result else {
            return XCTFail("最新の地点詳細にならなかった: \(result)")
        }
        XCTAssertNil(presentation.summary.kind)
    }

    func testDescriptionIsPassedThrough() async throws {
        var spots = BundleFixtures.validSpots()
        spots[0]["description"] = "体験授業を行う教室です。"
        let result = try await mapClient(snapshot(spots: spots)).spotDetail(CanonicalSpotID(rawValue: "mb_2f_cl_001"))

        guard case .fresh(let presentation) = result else {
            return XCTFail("最新の地点詳細にならなかった: \(result)")
        }
        XCTAssertEqual(presentation.descriptionText, "体験授業を行う教室です。")
    }

    func testUnconfirmedSnapshotIsSavedWithVersionAndDates() async throws {
        let result = try await mapClient(snapshot(isConfirmedLatest: false, lastConfirmedAt: confirmedAt))
            .spotDetail(CanonicalSpotID(rawValue: "mb_2f_cl_001"))

        guard case .saved(_, let metadata) = result else {
            return XCTFail("保存版にならなかった: \(result)")
        }
        XCTAssertEqual(metadata.bundleVersion, 42)
        XCTAssertEqual(metadata.publishedAt, BundleSpotCatalog.parseRFC3339("2026-11-01T09:00:00Z"))
        XCTAssertEqual(metadata.lastConfirmedAt, confirmedAt)
        XCTAssertEqual(metadata.detail, "版 42・2026/11/01 18:00 公開・最終確認 2026/11/01 18:05")
    }

    func testNeverConfirmedSnapshotSaysLatestIsUnknown() async throws {
        let result = try await mapClient(snapshot(isConfirmedLatest: false))
            .spotDetail(CanonicalSpotID(rawValue: "mb"))

        guard case .saved(_, let metadata) = result else {
            return XCTFail("保存版にならなかった: \(result)")
        }
        XCTAssertNil(metadata.lastConfirmedAt)
        XCTAssertEqual(metadata.detail, "版 42・2026/11/01 18:00 公開・最新情報は確認できていません")
    }

    func testMissingBundleThrowsInsteadOfUnknownSpot() async {
        do {
            _ = try await mapClient(nil).spotDetail(CanonicalSpotID(rawValue: "mb"))
            XCTFail("保存済みの版がないのに throw しなかった")
        } catch {
            XCTAssertEqual(error as? PublishedBundleSourceError, .notAvailable)
        }
    }

    // MARK: - SearchClient

    func testInitialContentListsAllSpotsInBundleOrder() async throws {
        let result = try await searchClient(snapshot()).initialContent()

        guard case .fresh(let initial) = result else {
            return XCTFail("最新の初期表示にならなかった: \(result)")
        }
        XCTAssertEqual(initial.spots.map(\.canonicalSpotID.rawValue), ["mb_2f_cl_001", "mb", "campus_lm_001"])
        XCTAssertEqual(initial.totalCount, 3)
    }

    func testInitialContentWithoutSpotsIsEmptyNotFailure() async throws {
        let result = try await searchClient(snapshot(spots: [])).initialContent()

        XCTAssertEqual(result, .empty(SearchClient.noPublishedSpotsMessage))
    }

    func testSearchMatchesNameIgnoringKanaAndWidth() async throws {
        var spots = BundleFixtures.validSpots()
        spots[2]["name"] = "こうくう神社"
        let client = searchClient(try snapshot(spots: spots))

        for text in ["コウクウ", "こうくう", "ｺｳｸｳ"] {
            let result = try await client.search(SearchQuery(text: text))
            guard case .fresh(let results) = result else {
                return XCTFail("\(text) で結果にならなかった: \(result)")
            }
            XCTAssertEqual(results.spots.map(\.canonicalSpotID.rawValue), ["campus_lm_001"], text)
        }
    }

    func testSearchMatchesSearchAliasesAndLatinCase() async throws {
        var spots = BundleFixtures.validSpots()
        spots[0]["search_aliases"] = ["2A", "Room 2A"]
        let result = try await searchClient(snapshot(spots: spots)).search(SearchQuery(text: "room 2a"))

        guard case .fresh(let results) = result else {
            return XCTFail("結果にならなかった: \(result)")
        }
        XCTAssertEqual(results.spots.map(\.canonicalSpotID.rawValue), ["mb_2f_cl_001"])
    }

    func testSearchDoesNotMatchCanonicalID() async throws {
        let result = try await searchClient(snapshot()).search(SearchQuery(text: "mb_2f_cl_001"))

        XCTAssertEqual(result, .empty(SearchClient.noMatchMessage))
    }

    func testCategoryFilterUsesKindAndExcludesSpotsWithoutKind() async throws {
        let client = searchClient(try snapshot())

        let facility = try await client.search(SearchQuery(text: "", categoryID: .facility))
        guard case .fresh(let results) = facility else {
            return XCTFail("結果にならなかった: \(facility)")
        }
        // 種別のない建物（mb）は、どのカテゴリにも含めない。
        XCTAssertEqual(results.spots.map(\.canonicalSpotID.rawValue), ["campus_lm_001"])

        let service = try await client.search(SearchQuery(text: "", categoryID: .service))
        XCTAssertEqual(service, .empty(SearchClient.noMatchMessage))
    }

    func testSearchOnUnconfirmedSnapshotIsSaved() async throws {
        let result = try await searchClient(snapshot(isConfirmedLatest: false)).search(SearchQuery(text: "教室"))

        guard case .saved(let results, let metadata) = result else {
            return XCTFail("保存版にならなかった: \(result)")
        }
        XCTAssertEqual(results.spots.map(\.canonicalSpotID.rawValue), ["mb_2f_cl_001", "mb"])
        XCTAssertEqual(metadata.bundleVersion, 42)
    }

    /// 保存版での0件は、最新の0件と区別できるよう保存版の説明を持つ（E2-5 §6 規則7）。
    func testNoMatchOnUnconfirmedSnapshotKeepsSavedMetadata() async throws {
        let result = try await searchClient(snapshot(isConfirmedLatest: false)).search(SearchQuery(text: "存在しない語"))

        guard case .empty(let message, let saved?) = result else {
            return XCTFail("保存版の0件にならなかった: \(result)")
        }
        XCTAssertEqual(message, SearchClient.noMatchMessage)
        XCTAssertEqual(saved.bundleVersion, 42)
    }

    func testNoPublishedSpotsOnUnconfirmedSnapshotKeepsSavedMetadata() async throws {
        let result = try await searchClient(snapshot(spots: [], isConfirmedLatest: false)).initialContent()

        guard case .empty(let message, let saved?) = result else {
            return XCTFail("保存版の0件にならなかった: \(result)")
        }
        XCTAssertEqual(message, SearchClient.noPublishedSpotsMessage)
        XCTAssertEqual(saved.bundleVersion, 42)
    }

    func testNoMatchOnConfirmedSnapshotHasNoSavedMetadata() async throws {
        let result = try await searchClient(snapshot()).search(SearchQuery(text: "存在しない語"))

        XCTAssertEqual(result, .empty(SearchClient.noMatchMessage, saved: nil))
    }

    func testSearchWithoutBundleThrowsInsteadOfEmpty() async {
        do {
            _ = try await searchClient(nil).search(SearchQuery(text: "教室"))
            XCTFail("保存済みの版がないのに throw しなかった")
        } catch {
            XCTAssertEqual(error as? PublishedBundleSourceError, .notAvailable)
        }
    }
}
