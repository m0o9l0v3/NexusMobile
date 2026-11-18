import MapKit
import SwiftUI

/// 地図の見た目とカメラの範囲（E1-4 改訂4 §6）。
///
/// Nexus の建物は Apple の地図に合わせないため、Apple の建物と数 m ずれる。ずれを目立たせないよう、
/// - 地図は `.flat`・`.muted` で描き、Apple の建物と施設を目立たなくする（§6「地図の見た目」）。
/// - 数 m のずれが見分けられる縮尺まで寄らせない（`minimumDistance`、§6「寄れる距離の下限」）。
/// - 傾けない（傾けると手前が拡大され、ずれが大きく見える）。
enum CampusMapCameraPolicy {
    /// 想定するずれの上限（m）。改訂4 §1 の「数 m」、独立した資料と Apple の地図の差の見込み 2〜4 m。
    static let assumedOffsetMeters = 4.0

    /// 寄れる距離の下限での、`assumedOffsetMeters` の画面上の長さの上限（pt）。
    /// 輪郭線を描かない半透明の塗りでは、縁が数 pt ずれても境目として読み取りにくい。
    /// 2 m のずれなら約 3pt、4 m で約 6〜7pt（画面の高さによる）に収める。
    static let maximumOffsetPoints = 7.0

    /// 傾き 0 の MapKit のカメラで、画面の縦に映る南北の長さ（m）をカメラの距離（m）で割った値。
    /// 地図の高さ 874pt（iPhone 17）・iOS 26.5 のシミュレーターで、`onMapCameraChange` の
    /// `camera.distance` と `region.span` から測った（2699 m → 1347 m、832 m → 415 m。どちらも 0.499）。
    static let visibleHeightPerDistance = 0.5

    /// `MapCameraBounds(minimumDistance:)` を与えたとき、MapKit が実際に止めるカメラの距離の比。
    /// 900 m を与えると 832 m で止まった（シミュレーターで測定）。ずれの見え方はこの距離で見積もる。
    static let observedStopRatio = 0.92

    /// 寄れる距離の下限（m、`MapCameraBounds` に渡す値）。実際には約 1100 m で止まり、画面の縦に約 550 m
    /// （iPhone 17 で約 0.63 m/pt）が映る。4 m のずれは約 6pt、2 m は約 3pt になる。建物（幅 50 m 前後）は 80pt ほど。
    static let minimumDistance = 1200.0

    /// 寄れる限りまで寄ったときのカメラの距離の見込み（m）。
    static var expectedClosestDistance: Double {
        minimumDistance * observedStopRatio
    }

    /// 引ける距離の上限（m）。制限しない（構内の外へも動かせる）。
    static let maximumDistance: Double? = nil

    /// 地図のカメラの範囲。`MapCameraBounds` は値を読み出せないため、試験は上の定数で確かめる。
    static var cameraBounds: MapCameraBounds {
        MapCameraBounds(minimumDistance: minimumDistance, maximumDistance: maximumDistance)
    }

    /// 地図の操作。傾けるのを除く。
    static let interactionModes: MapInteractionModes = [.pan, .zoom, .rotate]

    /// 本番の地図の見た目。
    static let elevation: MapStyle.Elevation = .flat

    static func mapStyle(elevation: MapStyle.Elevation = elevation) -> MapStyle {
        .standard(elevation: elevation, emphasis: .muted, pointsOfInterest: .excludingAll)
    }

    /// カメラの距離 `distance` m で、画面の高さ `viewHeightPoints` pt のときの 1pt あたりの長さ（m）。
    static func metersPerPoint(distance: Double, viewHeightPoints: Double) -> Double {
        distance * visibleHeightPerDistance / viewHeightPoints
    }

    /// 寄れる限りまで寄ったとき、`assumedOffsetMeters` のずれが画面で何 pt になるか。
    static func offsetPointsAtMinimumDistance(viewHeightPoints: Double) -> Double {
        assumedOffsetMeters / metersPerPoint(distance: expectedClosestDistance, viewHeightPoints: viewHeightPoints)
    }
}
