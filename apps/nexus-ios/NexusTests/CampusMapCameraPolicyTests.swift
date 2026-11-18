import MapKit
import SwiftUI
import XCTest
@testable import Nexus

/// 地図の見た目とカメラの範囲（E1-4 改訂4 §6）。
final class CampusMapCameraPolicyTests: XCTestCase {
    /// 地図の高さ（pt）。最も小さい対象の画面（iPhone SE 系 667pt）から大きい画面（Pro Max 956pt）まで。
    private let viewHeights: [Double] = [667, 874, 956]

    func testCameraBoundsUseMinimumDistance() {
        // 寄れる距離の下限は、構内全体の表示（数 km）より十分小さく、0 ではない。
        XCTAssertEqual(CampusMapCameraPolicy.minimumDistance, 1200)
        // 引く距離は制限しない。
        XCTAssertNil(CampusMapCameraPolicy.maximumDistance)
        _ = CampusMapCameraPolicy.cameraBounds
    }

    /// 寄れる限りまで寄っても、想定するずれ（4 m）は画面で `maximumOffsetPoints` 以下。
    func testAssumedOffsetStaysSmallAtClosestZoom() {
        for height in viewHeights {
            let points = CampusMapCameraPolicy.offsetPointsAtMinimumDistance(viewHeightPoints: height)
            XCTAssertLessThanOrEqual(points, CampusMapCameraPolicy.maximumOffsetPoints, "height \(height)pt: \(points)pt")
        }
    }

    /// 寄れる限りまで寄ったとき、建物（幅 50 m）が 44pt（HIG の最小タップ領域）より大きく見える。
    /// 下限を大きくしすぎて建物をタップしにくくしない。
    func testBuildingIsTappableAtClosestZoom() {
        for height in viewHeights {
            let metersPerPoint = CampusMapCameraPolicy.metersPerPoint(
                distance: CampusMapCameraPolicy.expectedClosestDistance,
                viewHeightPoints: height
            )
            XCTAssertGreaterThan(50 / metersPerPoint, NexusTheme.minimumTapTarget, "height \(height)pt")
        }
    }

    /// iPhone 17（874pt）で、シミュレーターで測った値と合う：900 m を与えて 832 m で止まり、縦に 415 m。
    func testMeasuredScaleMatchesSimulator() {
        let metersPerPoint = CampusMapCameraPolicy.metersPerPoint(distance: 832, viewHeightPoints: 874)
        XCTAssertEqual(metersPerPoint * 874, 415, accuracy: 5)
        XCTAssertEqual(900 * CampusMapCameraPolicy.observedStopRatio, 832, accuracy: 5)
    }

    /// 本番の地図は傾けられない（傾けると手前が拡大され、ずれが大きく見える）。
    func testInteractionModesExcludePitch() {
        XCTAssertFalse(CampusMapCameraPolicy.interactionModes.contains(.pitch))
        XCTAssertTrue(CampusMapCameraPolicy.interactionModes.contains(.pan))
        XCTAssertTrue(CampusMapCameraPolicy.interactionModes.contains(.zoom))
    }

    // MARK: - ズームの段階との関係

    /// 構内が大きく、`detailRatio` の幅まで寄れなくても、寄れる限りまで寄れば拡大表示になる。
    func testClosestZoomIsDetailEvenForLargeCampus() {
        let policy = CampusMapZoomPolicy(contentLatitudeSpan: 0.002)
        let closest = CampusMapCameraPolicy.expectedClosestDistance
        let visibleLatitudeDelta = closest * CampusMapCameraPolicy.visibleHeightPerDistance / 111_320
        // 幅だけでは overview（構内の 0.6 倍より広い）。
        XCTAssertEqual(policy.level(visibleLatitudeDelta: visibleLatitudeDelta), .overview)
        XCTAssertEqual(policy.level(visibleLatitudeDelta: visibleLatitudeDelta, cameraDistance: closest), .detail)
    }

    /// 寄れる限りの距離から離れていれば、これまでどおり幅で決める。
    func testFarCameraUsesLatitudeDelta() {
        let policy = CampusMapZoomPolicy(contentLatitudeSpan: 0.002)
        let far = CampusMapCameraPolicy.minimumDistance * 3
        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.01, cameraDistance: far), .overview)
        XCTAssertEqual(policy.level(visibleLatitudeDelta: 0.001, cameraDistance: far), .detail)
    }
}
