#if DEBUG
import Foundation

/// 現在地の画面確認用（DEBUG のみ、#29）。起動引数 `-NexusLocationFixture <case>`。
///
/// 地図データが届くまで本番の Map は未提供の表示なので、`-NexusMapKitCheck`（検証用の14棟）と
/// `-NexusPreviewScreen map` と一緒に使う。権限は使用中の許可済みとし、位置は決めた点を返す。
/// 座標は検証用の14棟（`CampusMapContent.offlineCheck`）の付近で、正式な構内の位置ではない。
enum CurrentLocationFixture: String, CaseIterable {
    /// 構内（教室棟と実習棟の間）を東へ少しずつ歩く。追従の確認にも使う。
    case onCampus
    /// 構内の南、約 500 m。「構内から離れています」。
    case offCampus
    /// 位置が届かない。取得の待ち時間のあと「現在地を取得できません」。
    case failure
    /// 「正確な位置情報」がオフで、一時的な正確な位置も断る。#25 の精度不足の表示。
    case reducedAccuracy

    static func fromLaunchArguments(_ arguments: [String]) -> CurrentLocationFixture? {
        guard let index = arguments.firstIndex(of: "-NexusLocationFixture"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return CurrentLocationFixture(rawValue: arguments[index + 1])
    }

    @MainActor
    var services: LocationServices {
        switch self {
        case .onCampus:
            let walk = (0..<12).map { step in
                CampusMapCoordinate(latitude: 42.77080, longitude: 141.68060 + Double(step) * 0.00004)
            }
            return LocationServices(permission: allowed, updates: ScriptedLocationUpdatesProvider(coordinates: walk))
        case .offCampus:
            return LocationServices(
                permission: allowed,
                updates: ScriptedLocationUpdatesProvider(coordinates: [
                    CampusMapCoordinate(latitude: 42.76500, longitude: 141.68150),
                ])
            )
        case .failure:
            return LocationServices(permission: allowed, updates: ScriptedLocationUpdatesProvider(coordinates: []))
        case .reducedAccuracy:
            return LocationServices(
                permission: PreviewLocationPermissionProvider(
                    snapshot: LocationPermissionSnapshot(authorization: .authorizedWhenInUse, accuracy: .reduced),
                    temporaryFullAccuracyAnswer: .reduced
                ),
                updates: ScriptedLocationUpdatesProvider(coordinates: [])
            )
        }
    }

    @MainActor
    private var allowed: LocationPermissionProviding {
        PreviewLocationPermissionProvider(snapshot: LocationPermissionSnapshot(authorization: .authorizedWhenInUse))
    }
}
#endif
