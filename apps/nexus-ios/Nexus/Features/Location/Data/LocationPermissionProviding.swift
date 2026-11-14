import CoreLocation
import Foundation

/// 位置情報の権限を読む・求める境界（#25）。
///
/// Store はこの protocol だけを見るので、単体試験では権限と精度を差し込める。
/// 現在地の取得・追従・青い点（#29）は `LocationUpdatesProviding` が担う。
@MainActor
protocol LocationPermissionProviding: AnyObject {
    /// いまの設定を読む。OS のダイアログは出さない。
    func currentSnapshot() async -> LocationPermissionSnapshot

    /// OS の「使用中のみ」の許可ダイアログを出し、利用者が答えたあとの設定を返す。
    /// すでに答えが決まっていればダイアログは出ず、いまの設定をすぐ返す。
    /// アプリの説明で「位置情報を使う」を押したときだけ呼ぶ（オーナー決定 X）。
    func requestWhenInUseAuthorization() async -> LocationPermissionSnapshot

    /// 「正確な位置情報」がオフのとき、一時的に正確な位置を使ってよいか OS のダイアログで尋ね、答えたあとの設定を返す
    /// （`requestTemporaryFullAccuracyAuthorization(withPurposeKey:)`、オーナー決定 1-a）。
    /// 精度がすでに正確・権限が無いときはダイアログを出さず、いまの設定をすぐ返す。
    func requestTemporaryFullAccuracy() async -> LocationPermissionSnapshot

    /// 設定アプリでの変更など、外から設定が変わったときに呼ぶ。
    var onChange: (@MainActor (LocationPermissionSnapshot) -> Void)? { get set }
}

/// Core Location を使う本番の実装。
@MainActor
final class CoreLocationPermissionProvider: NSObject, LocationPermissionProviding {
    var onChange: (@MainActor (LocationPermissionSnapshot) -> Void)?

    private let manager = CLLocationManager()
    private var pendingRequests: [CheckedContinuation<LocationPermissionSnapshot, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentSnapshot() async -> LocationPermissionSnapshot {
        await snapshot(of: manager)
    }

    func requestWhenInUseAuthorization() async -> LocationPermissionSnapshot {
        let current = await currentSnapshot()
        guard current.authorization == .notDetermined, current.servicesEnabled else {
            return current
        }
        return await withCheckedContinuation { continuation in
            pendingRequests.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestTemporaryFullAccuracy() async -> LocationPermissionSnapshot {
        let current = await currentSnapshot()
        guard current.accuracy == .reduced,
              current.servicesEnabled,
              current.authorization == .authorizedWhenInUse || current.authorization == .authorizedAlways
        else {
            return current
        }
        // 断られても例外にはならない。精度は答えたあとの設定から読む。
        try? await manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: LocationAcquisitionSettings.temporaryFullAccuracyPurposeKey
        )
        return await currentSnapshot()
    }

    private func snapshot(of manager: CLLocationManager) async -> LocationPermissionSnapshot {
        let authorization = Self.authorization(from: manager.authorizationStatus)
        let accuracy: LocationAccuracy = manager.accuracyAuthorization == .reducedAccuracy ? .reduced : .full
        // メインスレッドで呼ぶと画面が止まることがあると OS が警告するため、別スレッドで読む。
        let servicesEnabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        return LocationPermissionSnapshot(
            authorization: authorization,
            accuracy: accuracy,
            servicesEnabled: servicesEnabled
        )
    }

    private func authorizationDidChange() async {
        let snapshot = await currentSnapshot()
        // 生成直後にも呼ばれる。まだ答えが無いあいだは、待っている要求を終わらせない。
        if snapshot.authorization != .notDetermined {
            let requests = pendingRequests
            pendingRequests.removeAll()
            requests.forEach { $0.resume(returning: snapshot) }
        }
        onChange?(snapshot)
    }

    nonisolated static func authorization(from status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            // 未知の値は「使えない」側に倒す。架空の許可を作らない。
            return .denied
        }
    }
}

extension CoreLocationPermissionProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            await self.authorizationDidChange()
        }
    }
}

#if DEBUG
/// プレビューと画面確認用（`-NexusLocationPermissionPreview`）。OS には触れない。
@MainActor
final class PreviewLocationPermissionProvider: LocationPermissionProviding {
    var onChange: (@MainActor (LocationPermissionSnapshot) -> Void)?
    private var snapshot: LocationPermissionSnapshot
    private let answer: LocationPermissionSnapshot
    private let temporaryFullAccuracyAnswer: LocationAccuracy

    /// - Parameters:
    ///   - snapshot: 最初の設定。
    ///   - answer: OS のダイアログで利用者が答えたことにする設定。
    ///   - temporaryFullAccuracyAnswer: 一時的な正確な位置のダイアログで答えたことにする精度。
    init(
        snapshot: LocationPermissionSnapshot,
        answer: LocationPermissionSnapshot = LocationPermissionSnapshot(authorization: .authorizedWhenInUse),
        temporaryFullAccuracyAnswer: LocationAccuracy = .reduced
    ) {
        self.snapshot = snapshot
        self.answer = answer
        self.temporaryFullAccuracyAnswer = temporaryFullAccuracyAnswer
    }

    func requestTemporaryFullAccuracy() async -> LocationPermissionSnapshot {
        guard snapshot.accuracy == .reduced else { return snapshot }
        snapshot = LocationPermissionSnapshot(
            authorization: snapshot.authorization,
            accuracy: temporaryFullAccuracyAnswer,
            servicesEnabled: snapshot.servicesEnabled
        )
        return snapshot
    }

    func currentSnapshot() async -> LocationPermissionSnapshot {
        snapshot
    }

    func requestWhenInUseAuthorization() async -> LocationPermissionSnapshot {
        guard snapshot.authorization == .notDetermined else { return snapshot }
        snapshot = answer
        return snapshot
    }
}
#endif
