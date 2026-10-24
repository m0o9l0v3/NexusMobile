import XCTest
@testable import Nexus

/// bundle から描画面の内容を組み立てる処理（#26）。
final class CampusMapContentBundleTests: XCTestCase {

    private func validatedBundle(_ object: [String: Any] = BundleFixtures.bundleObject()) throws -> ParticipantBundle {
        let response = BundleFixtures.response(object)
        return try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
    }

    /// 検証器の不変条件に関係しない形の試験用。デコードだけを通す。
    private func decodedBundle(extraFeatures: [[String: Any]]) throws -> ParticipantBundle {
        let object = BundleFixtures.bundleObject(map: [
            "dataset_version": 7,
            "dataset_sha256": String(repeating: "a", count: 64),
            "geojson": BundleFixtures.geojson(extraFeatures: extraFeatures),
        ])
        return try JSONDecoder().decode(ParticipantBundle.self, from: BundleFixtures.data(object))
    }

    private func building(id: String, name: Any = NSNull(), rings: [[[Double]]]) -> [String: Any] {
        [
            "type": "Feature",
            "id": id,
            "geometry": ["type": "Polygon", "coordinates": rings],
            "properties": ["feature_type": "building", "name": name],
        ]
    }

    private func coordinate(_ position: [Double]) -> CampusMapCoordinate {
        CampusMapCoordinate(latitude: position[1], longitude: position[0])
    }

    // MARK: - 建物

    func testBuildingsComeFromBuildingFeaturesWithTheirNameAndOpenOutline() throws {
        let content = CampusMapContent(bundle: try validatedBundle())

        XCTAssertEqual(content.buildings.map(\.id), ["mb"])
        let building = try XCTUnwrap(content.buildings.first)
        XCTAssertEqual(building.name, "教室棟")
        // GeoJSON の閉じる点は除く。
        XCTAssertEqual(building.outline, [
            coordinate([141.6227, 42.7843]),
            coordinate([141.6229, 42.7843]),
            coordinate([141.6229, 42.7845]),
        ])
        XCTAssertEqual(building.holes, [])
    }

    func testBuildingWithoutNameHasNoLabelName() throws {
        let content = CampusMapContent(bundle: try decodedBundle(extraFeatures: [
            building(id: "ptb", rings: [[[141.0, 42.0], [141.001, 42.0], [141.001, 42.001], [141.0, 42.001], [141.0, 42.0]]]),
        ]))

        let ptb = try XCTUnwrap(content.buildings.first { $0.id == "ptb" })
        XCTAssertNil(ptb.name)
    }

    func testInnerRingsBecomeHoles() throws {
        let content = CampusMapContent(bundle: try decodedBundle(extraFeatures: [
            building(id: "ar", name: "アリーナ", rings: [
                [[141.0, 42.0], [141.004, 42.0], [141.004, 42.004], [141.0, 42.004], [141.0, 42.0]],
                [[141.001, 42.001], [141.003, 42.001], [141.003, 42.003], [141.001, 42.003], [141.001, 42.001]],
            ]),
        ]))

        let arena = try XCTUnwrap(content.buildings.first { $0.id == "ar" })
        XCTAssertEqual(arena.holes.count, 1)
        XCTAssertEqual(arena.holes.first?.count, 4)
    }

    func testNoMapMeansNoBuildings() throws {
        let object = BundleFixtures.bundleObject(spots: [], map: NSNull())
        let content = CampusMapContent(bundle: try validatedBundle(object))

        XCTAssertEqual(content.buildings, [])
        XCTAssertEqual(content.pins, [])
    }

    // MARK: - ピン

    func testPinsFollowBundleOrderWithSpotNamesAndPlacementPoints() throws {
        let content = CampusMapContent(bundle: try validatedBundle())
        let mb = try XCTUnwrap(content.buildings.first)

        XCTAssertEqual(content.pins.map(\.id), ["mb_2f_cl_001", "mb", "campus_lm_001"])
        XCTAssertEqual(content.pins.map(\.name), ["2A教室", "教室棟", "航空神社"])
        XCTAssertEqual(content.pins[0].coordinate, coordinate(BundleFixtures.roomPoint))
        XCTAssertEqual(content.pins[2].coordinate, coordinate(BundleFixtures.landmarkPoint))
        // 建物の spot には placement.point が無い（§5.2）ため、建物のラベルと同じ点に置く。
        XCTAssertEqual(content.pins[1].coordinate, mb.labelCoordinate)
    }

    func testSpotWithoutPlacementHasNoPin() throws {
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(id: "mb_1f_cl_009", name: "未配置の教室")]
        let content = CampusMapContent(bundle: try validatedBundle(BundleFixtures.bundleObject(spots: spots)))

        XCTAssertFalse(content.pins.contains { $0.id == "mb_1f_cl_009" })
        XCTAssertEqual(content.pins.count, 3)
    }

    func testSchemaExampleBuildsEveryPlacedSpotAsAPin() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // NexusTests
            .deletingLastPathComponent() // nexus-ios
            .deletingLastPathComponent() // apps
            .deletingLastPathComponent() // リポジトリのルート
            .appendingPathComponent("docs/schemas/examples/participant-bundle-v2.example.json")
        let bundle = try JSONDecoder().decode(ParticipantBundle.self, from: Data(contentsOf: url))

        let content = CampusMapContent(bundle: bundle)

        XCTAssertEqual(content.buildings.map(\.id), ["mb"])
        XCTAssertEqual(
            Set(content.pins.map(\.id)),
            Set(bundle.spots.filter { $0.placement != nil }.map(\.id))
        )
    }

    // MARK: - ラベルの位置

    func testRepresentativePointOfConvexShapeIsItsCentroid() {
        let square = [
            CampusMapCoordinate(latitude: 0, longitude: 0),
            CampusMapCoordinate(latitude: 0, longitude: 2),
            CampusMapCoordinate(latitude: 2, longitude: 2),
            CampusMapCoordinate(latitude: 2, longitude: 0),
        ]

        let point = CampusMapContent.representativePoint(outline: square)

        XCTAssertEqual(point.latitude, 1, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, 1, accuracy: 1e-9)
    }

    func testRepresentativePointStaysInsideAnLShapeWhoseCentroidIsOutside() {
        // 細い L 字。面積重心（約 2.87, 2.87）は建物の外に出る。
        let lShape = [
            CampusMapCoordinate(latitude: 0, longitude: 0),
            CampusMapCoordinate(latitude: 0, longitude: 10),
            CampusMapCoordinate(latitude: 1, longitude: 10),
            CampusMapCoordinate(latitude: 1, longitude: 1),
            CampusMapCoordinate(latitude: 10, longitude: 1),
            CampusMapCoordinate(latitude: 10, longitude: 0),
        ]

        let point = CampusMapContent.representativePoint(outline: lShape)

        // 重心と同じ緯度で建物の内側を通る区間は経度 0〜1 だけ。その中点。
        XCTAssertEqual(point.latitude, 54.5 / 19, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, 0.5, accuracy: 1e-9)
    }

    func testRepresentativePointAvoidsAHoleAtTheCentroid() {
        let outer = [
            CampusMapCoordinate(latitude: 0, longitude: 0),
            CampusMapCoordinate(latitude: 0, longitude: 4),
            CampusMapCoordinate(latitude: 4, longitude: 4),
            CampusMapCoordinate(latitude: 4, longitude: 0),
        ]
        let courtyard = [
            CampusMapCoordinate(latitude: 1, longitude: 1),
            CampusMapCoordinate(latitude: 1, longitude: 3),
            CampusMapCoordinate(latitude: 3, longitude: 3),
            CampusMapCoordinate(latitude: 3, longitude: 1),
        ]

        let point = CampusMapContent.representativePoint(outline: outer, holes: [courtyard])

        // 重心（2, 2）は中庭の中。同じ緯度の内側の区間は 0〜1 と 3〜4 で、同じ長さなら西を使う。
        XCTAssertEqual(point.latitude, 2, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, 0.5, accuracy: 1e-9)
    }

    func testRepresentativePointOfDegenerateShapeFallsBackToBoundsCenter() {
        let line = [
            CampusMapCoordinate(latitude: 0, longitude: 0),
            CampusMapCoordinate(latitude: 0, longitude: 2),
            CampusMapCoordinate(latitude: 0, longitude: 4),
        ]

        let point = CampusMapContent.representativePoint(outline: line)

        XCTAssertEqual(point.latitude, 0, accuracy: 1e-9)
        XCTAssertEqual(point.longitude, 2, accuracy: 1e-9)
    }
}
