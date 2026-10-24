import XCTest
@testable import Nexus

/// #24 の検証用データと MapKit の描画面の入口を確かめる。
@MainActor
final class CampusMapContentTests: XCTestCase {

    /// E1-1 の14棟。検証用データがこの集合とずれると、通信断の確認が14棟の確認にならない。
    private let e1_1BuildingIDs: Set<String> = [
        "ab", "amh", "aptr", "ar", "ctc_main", "ctc2", "dh",
        "dvh", "hgr_a", "hgr_b", "lbh", "mb", "ptb", "sab",
    ]

    func testOfflineCheckCoversTheFourteenE1_1BuildingsOnce() {
        let ids = CampusMapContent.offlineCheck.buildings.map(\.id)

        XCTAssertEqual(ids.count, 14)
        XCTAssertEqual(Set(ids), e1_1BuildingIDs)
    }

    func testEachOfflineCheckBuildingHasAnOutlineALabelAndAPin() {
        let content = CampusMapContent.offlineCheck
        let pinIDs = Set(content.pins.map(\.spotID.rawValue))

        for building in content.buildings {
            XCTAssertGreaterThanOrEqual(building.outline.count, 3, building.id)
            XCTAssertNotEqual(building.outline.first, building.outline.last, "閉じる点を含めない: \(building.id)")
            XCTAssertFalse(building.name?.isEmpty ?? true, building.id)

            let outlineBounds = building.outline.dropFirst().reduce(CampusMapBounds(building.outline[0])) {
                $0.including($1)
            }
            XCTAssertTrue(outlineBounds.contains(building.labelCoordinate), "ラベルが建物の外: \(building.id)")
            XCTAssertTrue(pinIDs.contains(building.id), "建物の Spot のピンが無い: \(building.id)")
        }
    }

    func testOfflineCheckPinsAreUnique() {
        let ids = CampusMapContent.offlineCheck.pins.map(\.id)

        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testBoundsCoverEveryOutlinePointAndPin() throws {
        let content = CampusMapContent.offlineCheck
        let bounds = try XCTUnwrap(content.bounds)

        for coordinate in content.buildings.flatMap(\.outline) + content.pins.map(\.coordinate) {
            XCTAssertTrue(bounds.contains(coordinate))
        }
    }

    func testEmptyContentHasNoBounds() {
        XCTAssertNil(CampusMapContent(buildings: [], pins: []).bounds)
    }

    func testMapKitProviderIsDistinctFromTheUnavailableDefault() {
        let provider = MapSurfaceProvider.mapKit(content: .offlineCheck)

        XCTAssertEqual(provider.identifier, "mapkit")
        XCTAssertNotEqual(provider.identifier, MapSurfaceProvider.unavailable.identifier)
    }
}
