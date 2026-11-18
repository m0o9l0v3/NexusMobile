import XCTest
@testable import Nexus

/// 地図のタップから建物を選ぶ判定（E1-4 改訂4 §6）。
final class CampusMapHitTestTests: XCTestCase {
    private static let originLatitude = 42.7700
    private static let originLongitude = 141.6790
    private static let projection = CampusMapHitTest.LocalProjection(
        origin: CampusMapCoordinate(latitude: originLatitude, longitude: originLongitude)
    )

    /// 原点から東へ `x` m、北へ `y` m の地点。
    private static func at(_ x: Double, _ y: Double) -> CampusMapCoordinate {
        CampusMapCoordinate(
            latitude: originLatitude + y / CampusMapHitTest.LocalProjection.metersPerDegreeLatitude,
            longitude: originLongitude + x / projection.metersPerDegreeLongitude
        )
    }

    /// 南西の角が (x, y) m、幅 `width` m・奥行き `depth` m の長方形の建物。
    private static func building(
        _ id: String,
        x: Double,
        y: Double,
        width: Double,
        depth: Double,
        holes: [[CampusMapCoordinate]] = []
    ) -> CampusMapContent.Building {
        CampusMapContent.Building(
            id: id,
            name: id,
            outline: [at(x, y), at(x + width, y), at(x + width, y + depth), at(x, y + depth)],
            holes: holes,
            labelCoordinate: at(x + width / 2, y + depth / 2)
        )
    }

    private func hit(_ x: Double, _ y: Double, in buildings: [CampusMapContent.Building], tolerance: Double = 5) -> String? {
        CampusMapHitTest.building(at: Self.at(x, y), in: buildings, toleranceMeters: tolerance)?.id
    }

    // MARK: - 内側・広げた範囲

    func testTapInsideSelectsBuilding() {
        let a = Self.building("a", x: 0, y: 0, width: 40, depth: 20)
        XCTAssertEqual(hit(20, 10, in: [a]), "a")
    }

    /// Apple の建物とのずれ（2〜4 m）の分、形の外側をタップしても当たる。
    func testTapJustOutsideWithinToleranceSelectsBuilding() {
        let a = Self.building("a", x: 0, y: 0, width: 40, depth: 20)
        XCTAssertEqual(hit(-3, 10, in: [a]), "a")
        XCTAssertEqual(hit(20, 24, in: [a]), "a")
        // 角の外側は角までの距離（3,4 → 5 m）。
        XCTAssertEqual(hit(43, 24, in: [a]), "a")
    }

    func testTapBeyondToleranceSelectsNothing() {
        let a = Self.building("a", x: 0, y: 0, width: 40, depth: 20)
        XCTAssertNil(hit(-6, 10, in: [a]))
        XCTAssertNil(hit(44, 24, in: [a]))
    }

    /// 中庭（穴）の中は建物の外。中庭の縁の近くなら、広げた範囲で当たる。
    func testHoleIsOutsideButEdgeToleranceApplies() {
        let hole = [Self.at(10, 10), Self.at(50, 10), Self.at(50, 50), Self.at(10, 50)]
        let a = Self.building("a", x: 0, y: 0, width: 60, depth: 60, holes: [hole])
        XCTAssertNil(hit(30, 30, in: [a]))
        XCTAssertEqual(hit(12, 30, in: [a]), "a")
        XCTAssertEqual(hit(5, 30, in: [a]), "a")
    }

    // MARK: - 隣り合う・重なる建物

    /// 2 m の隙間で隣り合う2棟。境目のタップは近いほうの建物になる。
    func testAdjacentBuildingsChooseNearest() {
        let west = Self.building("west", x: 0, y: 0, width: 30, depth: 20)
        let east = Self.building("east", x: 32, y: 0, width: 30, depth: 20)
        let buildings = [west, east]
        XCTAssertEqual(hit(30.5, 10, in: buildings), "west")
        XCTAssertEqual(hit(31.5, 10, in: buildings), "east")
        // 内側は、隣の広げた範囲に入っていても内側の建物。
        XCTAssertEqual(hit(29, 10, in: buildings), "west")
        XCTAssertEqual(hit(33, 10, in: buildings), "east")
    }

    /// ちょうど中間（同じ距離）なら、面積の小さい建物。
    func testEqualDistancePrefersSmallerBuilding() {
        let large = Self.building("large", x: 0, y: 0, width: 30, depth: 40)
        let small = Self.building("small", x: 32, y: 0, width: 10, depth: 40)
        XCTAssertEqual(hit(31, 20, in: [large, small]), "small")
        XCTAssertEqual(hit(31, 20, in: [small, large]), "small")
    }

    /// 面積も同じなら ID の辞書順。並び順に左右されない。
    func testEqualDistanceAndAreaPrefersLowerID() {
        let b = Self.building("b", x: 0, y: 0, width: 30, depth: 20)
        let a = Self.building("a", x: 32, y: 0, width: 30, depth: 20)
        XCTAssertEqual(hit(31, 10, in: [b, a]), "a")
        XCTAssertEqual(hit(31, 10, in: [a, b]), "a")
    }

    /// 形が重なっているときは、小さい建物を選ぶ（大きい建物は外側から選べる）。
    func testOverlappingBuildingsPreferSmallerInside() {
        let outer = Self.building("outer", x: 0, y: 0, width: 80, depth: 60)
        let inner = Self.building("inner", x: 20, y: 20, width: 20, depth: 20)
        XCTAssertEqual(hit(30, 30, in: [outer, inner]), "inner")
        XCTAssertEqual(hit(30, 30, in: [inner, outer]), "inner")
        XCTAssertEqual(hit(5, 5, in: [outer, inner]), "outer")
    }

    /// 形が3点未満の建物は判定に使わない。
    func testDegenerateOutlineIsIgnored() {
        let broken = CampusMapContent.Building(
            id: "broken",
            name: nil,
            outline: [Self.at(0, 0), Self.at(10, 0)],
            labelCoordinate: Self.at(5, 0)
        )
        XCTAssertNil(hit(5, 0, in: [broken]))
    }

    // MARK: - 広げる幅

    func testToleranceIsAtLeastMinimumAndGrowsWithScale() {
        XCTAssertEqual(CampusMapHitTest.toleranceMeters(metersPerPoint: 0.1), CampusMapHitTest.minimumToleranceMeters)
        XCTAssertEqual(CampusMapHitTest.toleranceMeters(metersPerPoint: 1), 22, accuracy: 0.001)
        XCTAssertEqual(CampusMapHitTest.toleranceMeters(metersPerPoint: 0), CampusMapHitTest.minimumToleranceMeters)
        XCTAssertEqual(CampusMapHitTest.toleranceMeters(metersPerPoint: .nan), CampusMapHitTest.minimumToleranceMeters)
    }

    /// 広げる幅は、想定するずれ（4 m）より大きい。
    func testMinimumToleranceCoversAssumedOffset() {
        XCTAssertGreaterThan(CampusMapHitTest.minimumToleranceMeters, CampusMapCameraPolicy.assumedOffsetMeters)
    }

    // MARK: - 建物から地点へ

    func testSpotIDPrefersBuildingPinInThatBuilding() {
        let a = Self.building("mb", x: 0, y: 0, width: 40, depth: 20)
        let content = CampusMapContent(
            buildings: [a],
            pins: [
                CampusMapContent.Pin(spotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"), name: "2A教室", coordinate: Self.at(5, 5), kind: .room, buildingID: "mb"),
                CampusMapContent.Pin(spotID: CanonicalSpotID(rawValue: "mb_spot"), name: "教室棟", coordinate: Self.at(20, -5), kind: .building, buildingID: "mb"),
            ]
        )
        XCTAssertEqual(CampusMapHitTest.spotID(at: Self.at(20, 10), in: content, toleranceMeters: 5)?.rawValue, "mb_spot")
    }

    func testSpotIDFallsBackToSameIDPin() {
        let a = Self.building("mb", x: 0, y: 0, width: 40, depth: 20)
        let content = CampusMapContent(
            buildings: [a],
            pins: [CampusMapContent.Pin(spotID: CanonicalSpotID(rawValue: "mb"), name: "教室棟", coordinate: Self.at(20, 10))]
        )
        XCTAssertEqual(CampusMapHitTest.spotID(at: Self.at(20, 10), in: content, toleranceMeters: 5)?.rawValue, "mb")
    }

    /// 建物の Spot が公開されていない建物は選ばず、範囲内の次に近い建物を選ぶ。
    func testBuildingWithoutSpotIsSkipped() {
        let unpublished = Self.building("hidden", x: 0, y: 0, width: 30, depth: 20)
        let published = Self.building("ab", x: 33, y: 0, width: 30, depth: 20)
        let content = CampusMapContent(
            buildings: [unpublished, published],
            pins: [CampusMapContent.Pin(spotID: CanonicalSpotID(rawValue: "ab"), name: "管理棟", coordinate: Self.at(45, -5), kind: .building, buildingID: "ab")]
        )
        XCTAssertEqual(CampusMapHitTest.spotID(at: Self.at(31, 10), in: content, toleranceMeters: 5)?.rawValue, "ab")
        XCTAssertNil(CampusMapHitTest.spotID(at: Self.at(10, 10), in: content, toleranceMeters: 5))
    }

    /// 検証用の14棟（`offlineCheck`）では、どの建物の中心をタップしても、その建物の Spot が選ばれる。
    func testOfflineCheckFixtureEveryBuildingSelectable() {
        let content = CampusMapContent.offlineCheck
        for building in content.buildings {
            XCTAssertEqual(
                CampusMapHitTest.spotID(at: building.labelCoordinate, in: content, toleranceMeters: 5)?.rawValue,
                building.id
            )
        }
    }

    // MARK: - 平面の計算

    func testDistanceToSegment() {
        let a = CampusMapHitTest.Point(x: -10, y: 3)
        let b = CampusMapHitTest.Point(x: 10, y: 3)
        XCTAssertEqual(CampusMapHitTest.distanceFromOrigin(toSegment: a, b), 3, accuracy: 1e-9)
        let c = CampusMapHitTest.Point(x: 3, y: 4)
        XCTAssertEqual(CampusMapHitTest.distanceFromOrigin(toSegment: c, CampusMapHitTest.Point(x: 13, y: 4)), 5, accuracy: 1e-9)
        XCTAssertEqual(CampusMapHitTest.distanceFromOrigin(toSegment: c, c), 5, accuracy: 1e-9)
    }

    /// 平面への写し方は、緯度 42.77° で 1 m の誤差が 1 cm 未満。
    func testProjectionScale() {
        let point = Self.projection.project(Self.at(100, 50))
        XCTAssertEqual(point.x, 100, accuracy: 0.01)
        XCTAssertEqual(point.y, 50, accuracy: 0.01)
    }
}
