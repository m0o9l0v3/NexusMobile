import XCTest
@testable import Nexus

/// 選んだ地点の強調とカメラの移動先（#28）。
final class CampusMapFocusTests: XCTestCase {

    private func content() throws -> CampusMapContent {
        let response = BundleFixtures.response(BundleFixtures.bundleObject())
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        return CampusMapContent(bundle: bundle)
    }

    private let room = CanonicalSpotID(rawValue: "mb_2f_cl_001")
    private let landmark = CanonicalSpotID(rawValue: "campus_lm_001")

    // MARK: - 強調

    func testRoomHighlightsItsBuilding() throws {
        XCTAssertEqual(CampusMapFocus.highlightedBuildingID(for: room, in: try content()), "mb")
    }

    func testBuildingSpotHighlightsItself() throws {
        XCTAssertEqual(CampusMapFocus.highlightedBuildingID(for: CanonicalSpotID(rawValue: "mb"), in: try content()), "mb")
    }

    /// 建物の外の地点では建物を強調しない。
    func testLandmarkHighlightsNoBuilding() throws {
        XCTAssertNil(CampusMapFocus.highlightedBuildingID(for: landmark, in: try content()))
    }

    // MARK: - 地図上に無い地点

    /// 未掲載の地点・大文字小文字だけ違う ID は、別の地点に置き換えず、何も強調しない・動かさない。
    func testUnknownOrCaseDifferentIDNeitherHighlightsNorMoves() throws {
        let content = try content()
        for id in ["does_not_exist", "MB_2F_CL_001"] {
            let spotID = CanonicalSpotID(rawValue: id)
            XCTAssertNil(CampusMapFocus.pin(for: spotID, in: content), id)
            XCTAssertNil(CampusMapFocus.highlightedBuildingID(for: spotID, in: content), id)
            XCTAssertNil(CampusMapFocus.region(for: spotID, in: content, visibleLatitudeDelta: nil), id)
        }
    }

    func testNoSelectionDoesNotMove() throws {
        XCTAssertNil(CampusMapFocus.region(for: nil, in: try content(), visibleLatitudeDelta: 0.01))
    }

    // MARK: - カメラの移動先

    /// 構内全体から選ぶと、拡大表示の縮尺まで寄り、ピンを中央より上に置く。
    func testMovesIntoDetailLevelWithThePinAboveCenter() throws {
        let content = try content()
        let policy = try XCTUnwrap(CampusMapZoomPolicy(content: content))
        let pin = try XCTUnwrap(CampusMapFocus.pin(for: room, in: content))

        let region = try XCTUnwrap(CampusMapFocus.region(for: room, in: content, visibleLatitudeDelta: 1.0))

        XCTAssertEqual(policy.level(visibleLatitudeDelta: region.latitudeDelta), .detail)
        XCTAssertEqual(region.center.longitude, pin.coordinate.longitude)
        XCTAssertLessThan(region.center.latitude, pin.coordinate.latitude, "ピンが中央より上に来ない")
        let top = region.center.latitude + region.latitudeDelta / 2
        XCTAssertLessThan(pin.coordinate.latitude, top, "ピンが画面の外に出る")
    }

    /// 利用者がもっと寄せていれば、その縮尺を保つ。
    func testKeepsACloserZoomTheUserChose() throws {
        let content = try content()
        let region = try XCTUnwrap(CampusMapFocus.region(for: landmark, in: content, visibleLatitudeDelta: 0.00005))

        XCTAssertEqual(region.latitudeDelta, 0.00005)
    }
}
