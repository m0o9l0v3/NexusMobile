import Foundation

/// 現在地の取得・青い点・追従（#29）。
///
/// - 取得は Map の現在地ボタン（`currentLocationButtonTapped()`）からだけ始める。Map を開いただけでは
///   取得も追従もせず、アプリの説明も出さない（#25 の決定 A、オーナー決定 3-a）。
/// - 権限は `LocationPermissionStore`（#25）に任せる。`allowed` になったら `onReady` で取得を始め、
///   失敗は `reportAcquisitionFailure()`、成功は `reportAcquisitionSuccess()` で返す。
///   「もう一度試す」は `onRetryAcquisition` で受ける。
/// - 追従はボタンを押したときだけ始め、利用者が地図を動かす・拡大縮小すると止める（Apple のマップと同じ）。
/// - 構内から離れていても青い点は出し、「構内から離れています」を出す。カメラは構内に残す（オーナー決定 2-a）。
///   地図の内容が無ければ構内かどうかを判断しない。
/// - 架空の現在地は置かない。使える点が届くまで青い点は出さない。
@MainActor
@Observable
final class CurrentLocationStore {
    enum Phase: Equatable, Sendable {
        /// 取得していない。
        case idle
        /// 取得を始め、最初の使える点を待っている。
        case locating
        /// 現在地がある。青い点を出す。
        case tracking
        /// 待ち時間内に使える点が届かなかった。理由の表示（「もう一度試す」）は LocationPermissionStore が出す。
        case failed
    }

    /// 追従中にカメラを移す先。`revision` は、同じ位置のままボタンを押し直したときにも移し直すための通し番号。
    struct CameraTarget: Equatable, Sendable {
        let coordinate: CampusMapCoordinate
        let revision: Int
    }

    let permission: LocationPermissionStore
    let settings: LocationAcquisitionSettings

    private(set) var phase: Phase = .idle
    private(set) var fix: LocationFix?
    private(set) var isFollowing = false
    /// 余白を足した構内の範囲。地図の内容が無ければ nil。
    private(set) var campusArea: CampusMapBounds?
    /// 地図（MapKit の描画面）が出ているか。出ていなければ現在地ボタンを出さない。
    private(set) var isMapShown = false
    private(set) var cameraTarget: CameraTarget?

    @ObservationIgnored private let updates: LocationUpdatesProviding
    @ObservationIgnored private let timeoutScheduler: LocationTimeoutScheduling
    @ObservationIgnored private var cancelTimeout: (@MainActor () -> Void)?
    @ObservationIgnored private var cameraRevision = 0

    init(
        permission: LocationPermissionStore,
        updates: LocationUpdatesProviding,
        settings: LocationAcquisitionSettings = .provisional,
        timeoutScheduler: LocationTimeoutScheduling? = nil
    ) {
        self.permission = permission
        self.updates = updates
        self.settings = settings
        self.timeoutScheduler = timeoutScheduler ?? TaskLocationTimeoutScheduler()
        // 経路の作業（出発地の「現在地」）で onReady を使うときは、`.useAsStartPoint` をここと分けて渡す。
        permission.onReady = { [weak self] action in
            guard action == .showCurrentLocation else { return }
            self?.beginFollowing()
        }
        permission.onRetryAcquisition = { [weak self] in
            self?.beginFollowing()
        }
    }

    var campusPresence: CampusPresence {
        CampusPresence.evaluate(fix, in: campusArea)
    }

    /// 「構内から離れています」を出すか。
    var showsOffCampusNotice: Bool {
        phase == .tracking && campusPresence == .offCampus
    }

    // MARK: - 操作

    /// 現在地ボタン。権限の確認（必要ならアプリの説明・一時的な正確な位置の確認）から始める。
    func currentLocationButtonTapped() async {
        await permission.requestLocation(for: .showCurrentLocation)
    }

    /// 利用者が地図を動かした・拡大縮小した。追従を止める（青い点と取得は続ける）。
    func userMovedCamera() {
        guard isFollowing else { return }
        isFollowing = false
        cameraTarget = nil
    }

    /// 地点を選んでカメラがそこへ移った。追従を止め、次の点でカメラを引き戻さない。
    func cameraMovedToSpot() {
        userMovedCamera()
    }

    // MARK: - 地図からの知らせ

    /// 地図が出た・内容が変わった。`bounds` は地図の内容の範囲（建物・ピン）。
    func mapAppeared(contentBounds bounds: CampusMapBounds?) {
        isMapShown = true
        campusArea = bounds?.expanded(byMeters: settings.campusMarginMeters)
        refreshCameraTarget()
    }

    /// 地図を離れた（タブの切替・背面）。取得を止める。戻っても自動では再開しない（決定 A・3-a）。
    func mapDisappeared() {
        isMapShown = false
        stop()
    }

    /// 権限の状態が変わった（設定アプリでの変更、一時的な正確な位置の期限切れなど）。
    /// 使えなくなったら取得を止め、青い点を消す。おおよその位置は出さない。
    func permissionStateChanged(_ state: LocationPermissionState) {
        switch state {
        case .allowed, .unavailable:
            return
        case .notAsked, .deferred, .reducedAccuracy, .denied:
            stop()
        }
    }

    /// 取得を止め、青い点を消す。
    func stop() {
        updates.stop()
        cancelTimeout?()
        cancelTimeout = nil
        phase = .idle
        fix = nil
        isFollowing = false
        cameraTarget = nil
    }

    // MARK: - 取得

    private func beginFollowing() {
        isFollowing = true
        switch phase {
        case .tracking:
            cameraRevision += 1
            refreshCameraTarget()
        case .locating:
            break
        case .idle, .failed:
            startUpdates()
        }
    }

    private func startUpdates() {
        phase = .locating
        fix = nil
        cameraTarget = nil
        updates.start(settings: settings) { [weak self] event in
            self?.handle(event)
        }
        cancelTimeout?()
        cancelTimeout = timeoutScheduler.schedule(after: settings.acquisitionTimeout) { [weak self] in
            self?.acquisitionTimedOut()
        }
    }

    /// 取得処理からの知らせ。試験からも直接呼ぶ。
    func handle(_ event: LocationUpdateEvent) {
        guard phase == .locating || phase == .tracking else { return }
        switch event {
        case .fix(let newFix):
            guard newFix.horizontalAccuracy >= 0,
                  newFix.horizontalAccuracy <= settings.maximumHorizontalAccuracy
            else { return }
            if phase == .tracking, let fix,
               newFix.timestamp.timeIntervalSince(fix.timestamp) < settings.minimumUpdateInterval.timeInterval {
                return
            }
            fix = newFix
            if phase == .locating {
                phase = .tracking
                cancelTimeout?()
                cancelTimeout = nil
                permission.reportAcquisitionSuccess()
            }
            refreshCameraTarget()
        case .unavailable:
            // 待ち時間（取得中）で判断する。追従中なら最後の点を残す。
            break
        }
    }

    private func acquisitionTimedOut() {
        guard phase == .locating else { return }
        updates.stop()
        cancelTimeout = nil
        phase = .failed
        isFollowing = false
        cameraTarget = nil
        permission.reportAcquisitionFailure()
    }

    /// 追従中で構内（または判断できない）なら、カメラを現在地へ。構内から離れていれば追従をやめ、カメラは構内に残す。
    private func refreshCameraTarget() {
        guard isFollowing, let fix else {
            cameraTarget = nil
            return
        }
        if campusPresence == .offCampus {
            isFollowing = false
            cameraTarget = nil
            return
        }
        cameraTarget = CameraTarget(coordinate: fix.coordinate, revision: cameraRevision)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
