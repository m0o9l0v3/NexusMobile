import CoreLocation
import Foundation

/// 現在地を取得する境界（#29）。
///
/// `CurrentLocationStore` はこの protocol だけを見るので、単体試験では位置・失敗・精度を差し込める。
/// 権限を読む・求めるのは `LocationPermissionProviding`（#25）で、ここでは扱わない。
/// 取得は、権限が `allowed` になってから（`LocationPermissionStore.onReady`）だけ始める。
@MainActor
protocol LocationUpdatesProviding: AnyObject {
    /// 取得を始める。`onEvent` はメインスレッドで呼ぶ。すでに取得中なら、前の取得を止めてから始める。
    /// 配信が取り消し以外で終わったら `.ended` を一度だけ送る。
    func start(settings: LocationAcquisitionSettings, onEvent: @escaping @MainActor (LocationUpdateEvent) -> Void)
    /// 取得を止める。止めたあとは `onEvent` を呼ばない。
    func stop()
}

/// 待ち時間の計り方。試験では手で時間切れにする。
@MainActor
protocol LocationTimeoutScheduling {
    /// `delay` のあとに `action` を呼ぶ。返したものを呼ぶと取り消す。
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void
}

/// 本番の待ち時間。
struct TaskLocationTimeoutScheduler: LocationTimeoutScheduling {
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }
}

/// Core Location の `CLLocationUpdate.liveUpdates` を使う本番の実装（iOS 17+、診断の値は iOS 18+）。
///
/// `CLLocationManager` の delegate（`startUpdatingLocation`）ではなくこちらを選んだ理由：
/// - 取得の開始と終了が Task の開始と取り消しにそのまま対応し、Map を離れたときに止め忘れにくい。
/// - iOS 18 の `CLServiceSession` を持っている間だけ使用中の位置情報を使う、と明示できる。
///   セッションは許可を求めるダイアログを出しうるが、ここは `allowed` になってから呼ぶので出ない。
/// - 背面に回ると OS が自動で配信を止める（背面での取得はしない。`CLBackgroundActivitySession` は使わない）。
@MainActor
final class CoreLocationUpdatesProvider: LocationUpdatesProviding {
    private var task: Task<Void, Never>?
    private var session: CLServiceSession?

    func start(settings: LocationAcquisitionSettings, onEvent: @escaping @MainActor (LocationUpdateEvent) -> Void) {
        stop()
        session = CLServiceSession(authorization: .whenInUse)
        let configuration = Self.liveConfiguration(for: settings.activity)
        task = Task { @MainActor in
            do {
                for try await update in CLLocationUpdate.liveUpdates(configuration) {
                    guard !Task.isCancelled else { return }
                    // 「正確な位置情報」がオフのときの位置（おおよその位置）は使わない（オーナー決定 1-a）。
                    // 権限の変化は LocationPermissionStore が受け取り、CurrentLocationStore が取得を止める。
                    if update.accuracyLimited { continue }
                    if let location = update.location, location.horizontalAccuracy >= 0 {
                        onEvent(.fix(LocationFix(
                            coordinate: CampusMapCoordinate(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            ),
                            horizontalAccuracy: location.horizontalAccuracy,
                            timestamp: location.timestamp
                        )))
                    } else if update.locationUnavailable {
                        onEvent(.unavailable)
                    }
                }
                // 取り消し以外で配信が終わった。次の点は来ない（PR #185 のレビュー）。
                guard !Task.isCancelled else { return }
                onEvent(.ended)
            } catch {
                guard !Task.isCancelled else { return }
                onEvent(.ended)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        session?.invalidate()
        session = nil
    }

    private static func liveConfiguration(for activity: LocationAcquisitionSettings.Activity) -> CLLocationUpdate.LiveConfiguration {
        switch activity {
        case .default: return .default
        case .otherNavigation: return .otherNavigation
        case .fitness: return .fitness
        }
    }
}

#if DEBUG
/// 画面確認用（`-NexusLocationFixture`）。OS には触れず、決めた位置を順に返す。
@MainActor
final class ScriptedLocationUpdatesProvider: LocationUpdatesProviding {
    private let coordinates: [CampusMapCoordinate]
    private let interval: Duration
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - coordinates: 返す位置。空なら何も返さない（取得の待ち時間が過ぎて「現在地を取得できません」になる）。
    ///     最後の位置を返したあとは、そこに留まる。
    init(coordinates: [CampusMapCoordinate], interval: Duration = .seconds(1)) {
        self.coordinates = coordinates
        self.interval = interval
    }

    func start(settings: LocationAcquisitionSettings, onEvent: @escaping @MainActor (LocationUpdateEvent) -> Void) {
        stop()
        let coordinates = coordinates
        let interval = interval
        task = Task { @MainActor in
            for coordinate in coordinates {
                guard !Task.isCancelled else { return }
                onEvent(.fix(LocationFix(coordinate: coordinate, horizontalAccuracy: 8, timestamp: Date())))
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
#endif

/// 位置情報の権限と取得の境界の組（#25・#29）。合成ルート（`AppShellModel`）で1回だけ作る。
@MainActor
struct LocationServices {
    let permission: LocationPermissionProviding
    let updates: LocationUpdatesProviding
    var settings: LocationAcquisitionSettings = .provisional

    /// 本番：Core Location。
    static func live() -> LocationServices {
        LocationServices(permission: CoreLocationPermissionProvider(), updates: CoreLocationUpdatesProvider())
    }
}
