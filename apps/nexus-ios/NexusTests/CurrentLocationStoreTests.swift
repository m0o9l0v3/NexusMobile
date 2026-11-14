import XCTest
@testable import Nexus

/// 現在地の取得・青い点・追従（#29）の状態遷移。位置・失敗・精度はスタブで差し込み、待ち時間は手で切らす。
@MainActor
final class CurrentLocationStoreTests: XCTestCase {
    private let campus = CampusMapBounds(CampusMapCoordinate(latitude: 42.7700, longitude: 141.6790))
        .including(CampusMapCoordinate(latitude: 42.7730, longitude: 141.6840))
    private let onCampus = CampusMapCoordinate(latitude: 42.7710, longitude: 141.6810)
    /// 構内の南端から約 500 m。
    private let offCampus = CampusMapCoordinate(latitude: 42.7655, longitude: 141.6815)

    private func makeStore(
        _ snapshot: LocationPermissionSnapshot = .init(authorization: .authorizedWhenInUse),
        answer: LocationPermissionSnapshot? = nil,
        temporaryFullAccuracyAnswer: LocationAccuracy = .reduced,
        mapShown: Bool = true
    ) -> (CurrentLocationStore, StubLocationPermissionProvider, StubLocationUpdatesProvider, ManualTimeoutScheduler) {
        let permissionProvider = StubLocationPermissionProvider(
            snapshot,
            answer: answer,
            temporaryFullAccuracyAnswer: temporaryFullAccuracyAnswer
        )
        let updates = StubLocationUpdatesProvider()
        let timer = ManualTimeoutScheduler()
        let store = CurrentLocationStore(
            permission: LocationPermissionStore(provider: permissionProvider),
            updates: updates,
            timeoutScheduler: timer
        )
        if mapShown {
            store.mapAppeared(contentBounds: nil)
        }
        return (store, permissionProvider, updates, timer)
    }

    private func fix(_ coordinate: CampusMapCoordinate, accuracy: Double = 10, at seconds: TimeInterval = 0) -> LocationUpdateEvent {
        .fix(LocationFix(coordinate: coordinate, horizontalAccuracy: accuracy, timestamp: Date(timeIntervalSince1970: seconds)))
    }

    // MARK: - Map を開いただけでは何もしない（決定 A・3-a）

    func testOpeningMapDoesNotStartAcquisitionOrExplain() {
        let (store, permissionProvider, updates, _) = makeStore(.init(authorization: .notDetermined), mapShown: false)

        store.mapAppeared(contentBounds: campus)

        XCTAssertTrue(store.isMapShown)
        XCTAssertEqual(store.phase, .idle)
        XCTAssertFalse(store.isFollowing)
        XCTAssertEqual(updates.startCount, 0)
        XCTAssertFalse(store.permission.isExplanationPresented)
        XCTAssertEqual(permissionProvider.requestCount, 0)
        XCTAssertNil(store.fix)
    }

    // MARK: - 現在地ボタン → 権限 → 取得

    func testButtonWhenAllowedStartsAcquisitionAndFollowing() async {
        let (store, _, updates, timer) = makeStore()
        store.mapAppeared(contentBounds: campus)

        await store.currentLocationButtonTapped()

        XCTAssertEqual(updates.startCount, 1)
        XCTAssertEqual(store.phase, .locating)
        XCTAssertTrue(store.isFollowing)
        XCTAssertNil(store.fix, "使える点が届くまで青い点を出さない（架空の現在地なし）")
        XCTAssertEqual(timer.scheduledDelays, [LocationAcquisitionSettings.provisional.acquisitionTimeout])
    }

    func testButtonWhenNotAskedShowsExplanationAndDoesNotStart() async {
        let (store, _, updates, _) = makeStore(.init(authorization: .notDetermined))

        await store.currentLocationButtonTapped()

        XCTAssertTrue(store.permission.isExplanationPresented)
        XCTAssertEqual(updates.startCount, 0)
        XCTAssertEqual(store.phase, .idle)
    }

    func testAllowingInExplanationStartsAcquisition() async {
        let (store, _, updates, _) = makeStore(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse)
        )
        await store.currentLocationButtonTapped()

        await store.permission.confirmExplanation()

        XCTAssertEqual(updates.startCount, 1)
        XCTAssertEqual(store.phase, .locating)
        XCTAssertTrue(store.isFollowing)
    }

    func testDeniedDoesNotStartAndShowsGuidance() async {
        let (store, _, updates, _) = makeStore(.init(authorization: .denied))

        await store.currentLocationButtonTapped()

        XCTAssertEqual(updates.startCount, 0)
        XCTAssertEqual(store.permission.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    // MARK: - 停止後に終わった権限の確認（PR #185 のレビュー）

    func testLeavingMapBeforeExplanationAnswerDoesNotStartLater() async {
        let (store, _, updates, _) = makeStore(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse)
        )
        await store.currentLocationButtonTapped()

        store.mapDisappeared()
        await store.permission.confirmExplanation()

        XCTAssertEqual(updates.startCount, 0, "別のタブで取得を始めない")
        XCTAssertEqual(store.phase, .idle)
        XCTAssertFalse(store.isFollowing)
    }

    func testBackgroundStopBeforeExplanationAnswerDoesNotStartOnReturn() async {
        let (store, _, updates, _) = makeStore(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse)
        )
        await store.currentLocationButtonTapped()

        store.stop()
        await store.permission.confirmExplanation()

        XCTAssertEqual(updates.startCount, 0, "復帰時にボタンを押し直さず追従を始めない")
    }

    func testReadyWithoutButtonDoesNotStart() async {
        let (store, _, updates, _) = makeStore()

        // 経路の作業など、現在地ボタン以外から .showCurrentLocation が届いた場合。
        await store.permission.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(updates.startCount, 0)
    }

    func testRetryAfterLeavingMapDoesNotStart() async {
        let (store, _, updates, timer) = makeStore()
        await store.currentLocationButtonTapped()
        timer.fire()

        store.mapDisappeared()
        store.permission.retryAcquisition()
        await store.pendingRetry?.value

        XCTAssertEqual(updates.startCount, 1)
        XCTAssertNil(store.pendingRetry)
        XCTAssertEqual(store.phase, .idle)
    }

    /// 取得失敗のあとで「正確な位置情報」がオフになった（一時的な許可の期限切れなど）。
    func testRetryAfterAccuracyReducedAsksTemporaryFullAccuracy() async {
        let (store, permissionProvider, updates, timer) = makeStore(temporaryFullAccuracyAnswer: .full)
        await store.currentLocationButtonTapped()
        timer.fire()
        permissionProvider.simulateChange(.init(authorization: .authorizedWhenInUse, accuracy: .reduced))
        XCTAssertEqual(store.permission.state, .unavailable, "取得失敗が精度より優先される")

        store.permission.retryAcquisition()
        await store.pendingRetry?.value

        XCTAssertEqual(permissionProvider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(updates.startCount, 2)
        XCTAssertEqual(store.phase, .locating)
    }

    func testRetryAfterAccuracyReducedAndDeclinedShowsGuidanceWithoutStarting() async {
        let (store, permissionProvider, updates, timer) = makeStore(temporaryFullAccuracyAnswer: .reduced)
        await store.currentLocationButtonTapped()
        timer.fire()
        permissionProvider.simulateChange(.init(authorization: .authorizedWhenInUse, accuracy: .reduced))

        store.permission.retryAcquisition()
        await store.pendingRetry?.value

        XCTAssertEqual(permissionProvider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(updates.startCount, 1, "おおよその位置で取得を始めない")
        XCTAssertEqual(store.permission.state, .reducedAccuracy)
        XCTAssertEqual(store.permission.guidance?.actions, [.openSettings, .chooseStartManually], "案内を消さない")
    }

    func testFirstGrantWithReducedAccuracyAsksTemporaryAndStarts() async {
        let (store, permissionProvider, updates, _) = makeStore(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .full
        )
        await store.currentLocationButtonTapped()

        await store.permission.confirmExplanation()

        XCTAssertEqual(permissionProvider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(updates.startCount, 1, "ボタンを押し直さなくても始まる")
        XCTAssertTrue(store.isFollowing)
    }

    // MARK: - 精度不足（オーナー決定 1-a）

    func testReducedAccuracyGrantedTemporarilyStartsAcquisition() async {
        let (store, permissionProvider, updates, _) = makeStore(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .full
        )

        await store.currentLocationButtonTapped()

        XCTAssertEqual(permissionProvider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(updates.startCount, 1)
    }

    func testReducedAccuracyDeclinedDoesNotStartAndShowsGuidance() async {
        let (store, permissionProvider, updates, _) = makeStore(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .reduced
        )

        await store.currentLocationButtonTapped()

        XCTAssertEqual(permissionProvider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(updates.startCount, 0, "おおよその位置は使わない")
        XCTAssertEqual(store.permission.state, .reducedAccuracy)
        XCTAssertEqual(store.permission.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    func testAccuracyBecomingReducedWhileTrackingStopsAndClearsDot() async {
        let (store, permissionProvider, updates, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))
        XCTAssertNotNil(store.fix)

        // 一時的な正確な位置の期限切れなど。
        permissionProvider.simulateChange(.init(authorization: .authorizedWhenInUse, accuracy: .reduced))
        store.permissionStateChanged(store.permission.state)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertNil(store.fix)
        XCTAssertFalse(store.isFollowing)
        XCTAssertEqual(updates.stopCount, 1)
    }

    func testPermissionRevokedWhileTrackingStops() async {
        let (store, permissionProvider, _, _) = makeStore()
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))

        permissionProvider.simulateChange(.init(authorization: .denied))
        store.permissionStateChanged(store.permission.state)

        XCTAssertEqual(store.phase, .idle)
        XCTAssertNil(store.fix)
    }

    // MARK: - 取得の成功と失敗

    func testFirstUsableFixStartsTrackingAndReportsSuccess() async {
        let (store, _, _, timer) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()

        store.handle(fix(onCampus))

        XCTAssertEqual(store.phase, .tracking)
        XCTAssertEqual(store.fix?.coordinate, onCampus)
        XCTAssertEqual(timer.cancelCount, 1, "取得できたら待ち時間を取り消す")
        XCTAssertEqual(store.permission.state, .allowed)
    }

    func testInaccurateFixIsIgnored() async {
        let (store, _, _, _) = makeStore()
        await store.currentLocationButtonTapped()

        store.handle(fix(onCampus, accuracy: LocationAcquisitionSettings.provisional.maximumHorizontalAccuracy + 1))

        XCTAssertEqual(store.phase, .locating)
        XCTAssertNil(store.fix)
    }

    func testUnavailableEventAloneDoesNotFail() async {
        let (store, _, _, _) = makeStore()
        await store.currentLocationButtonTapped()

        store.handle(.unavailable)

        XCTAssertEqual(store.phase, .locating)
        XCTAssertNil(store.permission.guidance)
    }

    func testTimeoutWithoutFixReportsFailureWithRetry() async {
        let (store, _, updates, timer) = makeStore()
        await store.currentLocationButtonTapped()

        timer.fire()

        XCTAssertEqual(store.phase, .failed)
        XCTAssertFalse(store.isFollowing)
        XCTAssertEqual(updates.stopCount, 1)
        XCTAssertEqual(store.permission.state, .unavailable)
        XCTAssertEqual(store.permission.guidance?.actions, [.retry, .chooseStartManually])
    }

    func testRetryAfterFailureRestartsAcquisition() async {
        let (store, _, updates, timer) = makeStore()
        await store.currentLocationButtonTapped()
        timer.fire()

        store.permission.retryAcquisition()
        await store.pendingRetry?.value

        XCTAssertEqual(updates.startCount, 2)
        XCTAssertEqual(store.phase, .locating)
        XCTAssertTrue(store.isFollowing)
        XCTAssertEqual(store.permission.state, .allowed)

        store.handle(fix(onCampus))
        XCTAssertEqual(store.phase, .tracking)
        XCTAssertNil(store.permission.guidance)
    }

    func testTimeoutAfterTrackingIsIgnored() async {
        let (store, _, _, timer) = makeStore()
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))

        timer.fire()

        XCTAssertEqual(store.phase, .tracking)
        XCTAssertNil(store.permission.guidance)
    }

    func testEventsAfterStopAreIgnored() async {
        let (store, _, _, _) = makeStore()
        await store.currentLocationButtonTapped()
        store.stop()

        store.handle(fix(onCampus))

        XCTAssertEqual(store.phase, .idle)
        XCTAssertNil(store.fix)
    }

    func testFixesCloserThanMinimumIntervalAreSkipped() async {
        let (store, _, _, _) = makeStore()
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus, at: 0))
        let moved = CampusMapCoordinate(latitude: onCampus.latitude + 0.0001, longitude: onCampus.longitude)

        store.handle(fix(moved, at: 0.4))
        XCTAssertEqual(store.fix?.coordinate, onCampus)

        store.handle(fix(moved, at: 1.2))
        XCTAssertEqual(store.fix?.coordinate, moved)
    }

    // MARK: - 追従（オーナー決定 3-a）

    func testFollowingMovesCameraWithEachFix() async {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()

        store.handle(fix(onCampus, at: 0))
        XCTAssertEqual(store.cameraTarget?.coordinate, onCampus)

        let moved = CampusMapCoordinate(latitude: onCampus.latitude + 0.0002, longitude: onCampus.longitude)
        store.handle(fix(moved, at: 2))
        XCTAssertEqual(store.cameraTarget?.coordinate, moved)
    }

    func testUserPanStopsFollowingButKeepsDot() async {
        let (store, _, updates, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus, at: 0))

        store.userMovedCamera()
        let moved = CampusMapCoordinate(latitude: onCampus.latitude + 0.0002, longitude: onCampus.longitude)
        store.handle(fix(moved, at: 2))

        XCTAssertFalse(store.isFollowing)
        XCTAssertNil(store.cameraTarget, "動かした地図を次の点で引き戻さない")
        XCTAssertEqual(store.fix?.coordinate, moved, "青い点は動き続ける")
        XCTAssertEqual(updates.stopCount, 0)
    }

    func testSelectingSpotStopsFollowing() async {
        let (store, _, _, _) = makeStore()
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))

        store.cameraMovedToSpot()

        XCTAssertFalse(store.isFollowing)
        XCTAssertNil(store.cameraTarget)
    }

    func testTappingAgainResumesFollowingAndRecenters() async {
        let (store, _, updates, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))
        let first = store.cameraTarget
        store.userMovedCamera()

        await store.currentLocationButtonTapped()

        XCTAssertTrue(store.isFollowing)
        XCTAssertEqual(store.cameraTarget?.coordinate, onCampus)
        XCTAssertNotEqual(store.cameraTarget, first, "同じ位置でも移し直す")
        XCTAssertEqual(updates.startCount, 1, "取得中は始め直さない")
    }

    func testLeavingMapStopsAcquisitionAndDoesNotAutoRestart() async {
        let (store, _, updates, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus))

        store.mapDisappeared()
        store.mapAppeared(contentBounds: campus)

        XCTAssertEqual(updates.stopCount, 1)
        XCTAssertEqual(updates.startCount, 1)
        XCTAssertEqual(store.phase, .idle)
        XCTAssertNil(store.fix)
        XCTAssertFalse(store.isFollowing)
    }

    // MARK: - 構内の判定（オーナー決定 2-a）

    func testOffCampusShowsDotAndNoticeAndKeepsCamera() async {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()

        store.handle(fix(offCampus))

        XCTAssertEqual(store.fix?.coordinate, offCampus, "構外でも青い点は出す")
        XCTAssertEqual(store.campusPresence, .offCampus)
        XCTAssertTrue(store.showsOffCampusNotice)
        XCTAssertNil(store.cameraTarget, "カメラは構内に残す")
        XCTAssertFalse(store.isFollowing)
    }

    func testWalkingOffCampusWhileFollowingStopsFollowing() async {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        store.handle(fix(onCampus, at: 0))
        XCTAssertTrue(store.isFollowing)

        store.handle(fix(offCampus, at: 5))

        XCTAssertFalse(store.isFollowing)
        XCTAssertNil(store.cameraTarget)
        XCTAssertTrue(store.showsOffCampusNotice)
    }

    func testWithinMarginCountsAsOnCampus() async {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: campus)
        await store.currentLocationButtonTapped()
        // 南端から約 50 m（余白 100 m の内側）。
        let nearGate = CampusMapCoordinate(latitude: campus.minLatitude - 50 / 111_320, longitude: onCampus.longitude)

        store.handle(fix(nearGate))

        XCTAssertEqual(store.campusPresence, .onCampus)
        XCTAssertFalse(store.showsOffCampusNotice)
        XCTAssertEqual(store.cameraTarget?.coordinate, nearGate)
    }

    func testWithoutMapContentNoOffCampusCheck() async {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: nil)
        await store.currentLocationButtonTapped()

        store.handle(fix(offCampus))

        XCTAssertEqual(store.campusPresence, .unknown)
        XCTAssertFalse(store.showsOffCampusNotice)
        XCTAssertTrue(store.isFollowing)
    }

    func testOffCampusNoticeOnlyWhileTracking() {
        let (store, _, _, _) = makeStore()
        store.mapAppeared(contentBounds: campus)

        XCTAssertEqual(store.campusPresence, .unknown)
        XCTAssertFalse(store.showsOffCampusNotice)
    }

    // MARK: - 構内の範囲・カメラ・文言

    func testExpandedBoundsAddsMarginInMeters() {
        let expanded = campus.expanded(byMeters: 100)
        let latitudeMeters = (campus.minLatitude - expanded.minLatitude) * 111_320
        let longitudeMeters = (campus.minLongitude - expanded.minLongitude) * 111_320
            * cos((campus.minLatitude + campus.maxLatitude) / 2 * .pi / 180)

        XCTAssertEqual(latitudeMeters, 100, accuracy: 0.5)
        XCTAssertEqual(longitudeMeters, 100, accuracy: 0.5)
        XCTAssertFalse(expanded.contains(CampusMapCoordinate(latitude: campus.minLatitude - 150 / 111_320, longitude: onCampus.longitude)))
    }

    func testCameraRegionKeepsUserZoomWhenCloser() throws {
        let content = CampusMapContent.offlineCheck
        let wide = try XCTUnwrap(CurrentLocationCamera.region(centeredOn: onCampus, in: content, visibleLatitudeDelta: 1))
        let close = try XCTUnwrap(CurrentLocationCamera.region(centeredOn: onCampus, in: content, visibleLatitudeDelta: 0.0002))

        XCTAssertEqual(wide.center, onCampus)
        XCTAssertLessThan(wide.latitudeDelta, 1, "広すぎる表示からは寄せる")
        XCTAssertEqual(close.latitudeDelta, 0.0002, "寄せた縮尺は保つ")
        XCTAssertNil(CurrentLocationCamera.region(
            centeredOn: onCampus,
            in: CampusMapContent(buildings: [], pins: []),
            visibleLatitudeDelta: nil
        ))
    }

    func testButtonAccessibilityValue() {
        XCTAssertEqual(CurrentLocationAccessibilityText.buttonValue(phase: .locating, isFollowing: true), "取得中")
        XCTAssertEqual(CurrentLocationAccessibilityText.buttonValue(phase: .tracking, isFollowing: true), "追従中")
        XCTAssertEqual(CurrentLocationAccessibilityText.buttonValue(phase: .tracking, isFollowing: false), "追従していません")
        XCTAssertEqual(CurrentLocationAccessibilityText.buttonValue(phase: .idle, isFollowing: false), "")
        XCTAssertEqual(CurrentLocationAccessibilityText.offCampusTitle, "構内から離れています")
    }

    // MARK: - モック撤去

    /// 旧 Expo アプリの「現在地（仮）」のような固定の点を、どの状態でも置かない。
    func testNoPlaceholderLocationBeforeFix() async {
        let (store, _, _, timer) = makeStore()
        store.mapAppeared(contentBounds: campus)
        XCTAssertNil(store.fix)
        await store.currentLocationButtonTapped()
        XCTAssertNil(store.fix)
        timer.fire()
        XCTAssertNil(store.fix)
        XCTAssertNil(store.cameraTarget)
    }
}

// MARK: - Stubs

@MainActor
final class StubLocationUpdatesProvider: LocationUpdatesProviding {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var onEvent: (@MainActor (LocationUpdateEvent) -> Void)?

    func start(settings: LocationAcquisitionSettings, onEvent: @escaping @MainActor (LocationUpdateEvent) -> Void) {
        startCount += 1
        self.onEvent = onEvent
    }

    func stop() {
        stopCount += 1
        onEvent = nil
    }
}

@MainActor
final class ManualTimeoutScheduler: LocationTimeoutScheduling {
    private(set) var scheduledDelays: [Duration] = []
    private(set) var cancelCount = 0
    private var pending: (@MainActor () -> Void)?

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        scheduledDelays.append(delay)
        pending = action
        return { [weak self] in
            self?.cancelCount += 1
            self?.pending = nil
        }
    }

    /// 待ち時間を切らす。
    func fire() {
        let action = pending
        pending = nil
        action?()
    }
}
