import XCTest
@testable import Nexus

/// ズームに応じたピン・地点名の出し分け（#26）と、描画面に渡す内容の選び方。
final class CampusMapZoomPolicyTests: XCTestCase {

    private let room = CampusMapContent.Pin(
        spotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
        name: "2A教室",
        coordinate: CampusMapCoordinate(latitude: 42.7843, longitude: 141.6227),
        kind: .room
    )
    private let building = CampusMapContent.Pin(
        spotID: CanonicalSpotID(rawValue: "mb"),
        name: "教室棟",
        coordinate: CampusMapCoordinate(latitude: 42.7844, longitude: 141.6228),
        kind: .building,
        isNamedByBuildingLabel: true
    )
    private let landmark = CampusMapContent.Pin(
        spotID: CanonicalSpotID(rawValue: "campus_lm_001"),
        name: "航空神社",
        coordinate: CampusMapCoordinate(latitude: 42.7850, longitude: 141.6225),
        kind: .other
    )

    // MARK: - 段階

    /// 最初の表示（構内の幅の 1.25 倍）は構内全体の段階。
    func testInitialRegionIsOverview() {
        let policy = CampusMapZoomPolicy(contentLatitudeSpan: 0.004)

        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.004 * 1.25), .overview)
        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.004), .overview)
    }

    func testZoomingInPastTheRatioIsDetail() {
        let policy = CampusMapZoomPolicy(contentLatitudeSpan: 0.004)

        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.004 * CampusMapZoomPolicy.detailRatio), .detail)
        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.001), .detail)
    }

    /// 1棟だけのような小さいデータでも、少し拡大すれば地点名が出る。
    func testTinyContentUsesTheMinimumSpan() {
        let policy = CampusMapZoomPolicy(contentLatitudeSpan: 0)

        XCTAssertEqual(policy.contentLatitudeSpan, CampusMapZoomPolicy.minimumContentLatitudeSpan)
        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.0003), .detail)
    }

    func testEmptyContentHasNoPolicy() {
        XCTAssertNil(CampusMapZoomPolicy(content: CampusMapContent(buildings: [], pins: [])))
    }

    // MARK: - ピンと地点名

    func testOverviewHidesRoomPinsAndBuildingPinNames() {
        let pins = [room, building, landmark]

        XCTAssertEqual(
            pins.filter { CampusMapZoomPolicy.showsPin($0, at: .overview, focusedSpotID: nil) }.map(\.id),
            ["mb", "campus_lm_001"]
        )
        XCTAssertFalse(CampusMapZoomPolicy.showsPinName(building, at: .overview, focusedSpotID: nil))
        XCTAssertTrue(CampusMapZoomPolicy.showsPinName(landmark, at: .overview, focusedSpotID: nil))
    }

    func testDetailShowsEveryPinWithItsName() {
        for pin in [room, building, landmark] {
            XCTAssertTrue(CampusMapZoomPolicy.showsPin(pin, at: .detail, focusedSpotID: nil), pin.id)
            XCTAssertTrue(CampusMapZoomPolicy.showsPinName(pin, at: .detail, focusedSpotID: nil), pin.id)
        }
    }

    /// 建物のラベルで地点名が読めない（ラベルが無い・名前が違う）建物のピンは、地点名を省かない
    /// （PR #143 のレビュー、E2-5 §5.2）。
    func testBuildingPinNameStaysWhenTheLabelDoesNotShowIt() {
        let unlabeled = CampusMapContent.Pin(
            spotID: CanonicalSpotID(rawValue: "ptb"),
            name: "実習棟",
            coordinate: CampusMapCoordinate(latitude: 42.7846, longitude: 141.6230),
            kind: .building,
            isNamedByBuildingLabel: false
        )

        XCTAssertTrue(CampusMapZoomPolicy.showsPinName(unlabeled, at: .overview, focusedSpotID: nil))
    }

    /// 選択中の地点は構内全体の段階でも消さない。
    func testFocusedRoomStaysVisibleWithItsNameInOverview() {
        XCTAssertTrue(CampusMapZoomPolicy.showsPin(room, at: .overview, focusedSpotID: room.spotID))
        XCTAssertTrue(CampusMapZoomPolicy.showsPinName(room, at: .overview, focusedSpotID: room.spotID))
    }

    // MARK: - 描画面に渡す内容

    /// 保存版が無いだけでは「掲載なし」にしない（理由が分からなければ失敗、#31）。
    func testNoSavedVersionDrawsNothing() {
        XCTAssertEqual(
            MapContentState.resolve(.success(nil), absence: .unknown),
            .failed(MapContentStateMessage.loadFailed)
        )
    }

    func testBundleWithoutMapAndPinsDrawsNothing() throws {
        let object = BundleFixtures.bundleObject(spots: [], map: NSNull())
        let response = BundleFixtures.response(object)
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        let snapshot = PublishedBundleSnapshot(
            stored: StoredParticipantBundle(bundle: bundle, metadata: try PinnedFixtures.snapshot(version: 42).stored.metadata),
            isConfirmedLatest: true,
            lastConfirmedAt: nil
        )

        XCTAssertEqual(
            MapContentState.resolve(.success(snapshot), absence: .unknown),
            .empty(MapContentStateMessage.noMapInBundle)
        )
    }

    func testPublishedBundleIsDrawn() throws {
        let state = MapContentState.resolve(.success(try PinnedFixtures.snapshot(version: 1)), absence: .unknown)

        guard case .loaded(let content) = state else {
            return XCTFail("地図が描かれなかった: \(state)")
        }
        XCTAssertEqual(content.buildings.map(\.id), ["mb"])
        XCTAssertEqual(content.pins.count, 3)
    }
}
