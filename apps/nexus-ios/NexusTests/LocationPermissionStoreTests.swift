import CoreLocation
import XCTest
@testable import Nexus

/// 位置情報の権限フロー（#25）の状態遷移。権限と精度は `StubLocationPermissionProvider` で差し込む。
@MainActor
final class LocationPermissionStoreTests: XCTestCase {

    // MARK: - 最初の状態（説明も OS のダイアログも出さない）

    func testRefreshReadsStatusWithoutPromptingOrExplaining() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)

        await store.refresh()

        XCTAssertEqual(store.state, .notAsked)
        XCTAssertFalse(store.isExplanationPresented, "起動時・Map を開いたときに説明を出さない（決定 A）")
        XCTAssertEqual(provider.requestCount, 0)
        XCTAssertNil(store.guidance)
    }

    // MARK: - 未確認 → 説明

    func testFirstLocationActionShowsExplanationNotSystemDialog() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(outcome, .explanationPresented)
        XCTAssertTrue(store.isExplanationPresented)
        XCTAssertEqual(store.pendingAction, .useAsStartPoint)
        XCTAssertEqual(provider.requestCount, 0, "OS のダイアログは「位置情報を使う」まで出さない")
    }

    // MARK: - 後で

    func testLaterDoesNotPromptAndOffersManualStart() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)

        store.deferExplanation()

        XCTAssertEqual(store.state, .deferred)
        XCTAssertFalse(store.isExplanationPresented)
        XCTAssertNil(store.pendingAction)
        XCTAssertEqual(provider.requestCount, 0)
        XCTAssertEqual(store.guidance?.actions, [.chooseStartManually])
    }

    func testNextActionAfterLaterShowsExplanationAgain() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)
        store.deferExplanation()

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(outcome, .explanationPresented, "「後で」の次もアプリの説明から（決定 X）")
        XCTAssertTrue(store.isExplanationPresented)
        XCTAssertNil(store.guidance)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testDeferIsIgnoredWhenExplanationIsNotShown() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)
        await store.refresh()

        store.deferExplanation()

        XCTAssertEqual(store.state, .notAsked)
    }

    // MARK: - 位置情報を使う → OS の答え

    func testAllowLeadsToReadyAndHandsOffAction() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse)
        )
        let store = LocationPermissionStore(provider: provider)
        var handedOff: [LocationAction] = []
        store.onReady = { handedOff.append($0) }
        await store.requestLocation(for: .useAsStartPoint)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(outcome, .ready(.useAsStartPoint))
        XCTAssertEqual(store.state, .allowed)
        XCTAssertEqual(handedOff, [.useAsStartPoint])
        XCTAssertFalse(store.isExplanationPresented)
        XCTAssertNil(store.guidance)
    }

    func testAllowAfterLaterStillPromptsOnce() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse)
        )
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)
        store.deferExplanation()
        await store.requestLocation(for: .showCurrentLocation)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(outcome, .ready(.showCurrentLocation))
        XCTAssertEqual(store.state, .allowed)
    }

    func testDenyInSystemDialogShowsSettingsAndManualStart() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .denied)
        )
        let store = LocationPermissionStore(provider: provider)
        var readyCount = 0
        store.onReady = { _ in readyCount += 1 }
        await store.requestLocation(for: .useAsStartPoint)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(outcome, .unavailable(.denied(.userDenied)))
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
        XCTAssertEqual(readyCount, 0, "拒否で架空の現在地を渡さない")
    }

    func testReducedAccuracyAnswerIsNotUsedAsStartPoint() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse, accuracy: .reduced)
        )
        let store = LocationPermissionStore(provider: provider)
        var readyCount = 0
        store.onReady = { _ in readyCount += 1 }
        await store.requestLocation(for: .useAsStartPoint)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(outcome, .unavailable(.reducedAccuracy))
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
        XCTAssertEqual(readyCount, 0)
    }

    func testUnansweredSystemDialogReturnsToNotAsked() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .notDetermined)
        )
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)

        let outcome = await store.confirmExplanation()

        XCTAssertNil(outcome)
        XCTAssertEqual(store.state, .notAsked)
        XCTAssertFalse(store.isExplanationPresented)
        XCTAssertNil(store.guidance)
    }

    func testConfirmWithoutExplanationDoesNothing() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)
        await store.refresh()

        let outcome = await store.confirmExplanation()

        XCTAssertNil(outcome)
        XCTAssertEqual(provider.requestCount, 0)
    }

    // MARK: - すでに答えがある状態での操作（説明も OS のダイアログも出さない）

    func testAllowedActionIsReadyImmediately() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse))
        let store = LocationPermissionStore(provider: provider)

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(outcome, .ready(.showCurrentLocation))
        XCTAssertFalse(store.isExplanationPresented)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testAlwaysAuthorizationCountsAsAllowed() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .authorizedAlways)))

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(outcome, .ready(.showCurrentLocation))
    }

    func testDeniedActionGoesToGuidanceWithoutExplanation() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .denied))
        let store = LocationPermissionStore(provider: provider)

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(outcome, .unavailable(.denied(.userDenied)))
        XCTAssertFalse(store.isExplanationPresented)
        XCTAssertEqual(provider.requestCount, 0)
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    func testRestrictedOffersOnlyManualStart() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .restricted)))

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(outcome, .unavailable(.denied(.restricted)))
        XCTAssertEqual(store.guidance?.actions, [.chooseStartManually], "機能制限は設定で変えられないことがある")
    }

    func testLocationServicesOffIsDistinguishedFromDenial() async {
        // 位置情報サービスがオフのとき、OS は権限を denied と返す。
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(
            .init(authorization: .denied, servicesEnabled: false)
        ))

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(outcome, .unavailable(.denied(.servicesOff)))
        XCTAssertEqual(store.guidance?.message.title, "位置情報サービスがオフです")
    }

    func testLocationServicesOffBeforeAskingSkipsExplanation() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined, servicesEnabled: false))
        let store = LocationPermissionStore(provider: provider)

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(outcome, .unavailable(.denied(.servicesOff)))
        XCTAssertFalse(store.isExplanationPresented)
    }

    func testReducedAccuracyActionGoesToGuidance() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced)
        ))

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(outcome, .unavailable(.reducedAccuracy))
    }

    // MARK: - 一時的な正確な位置（#29、オーナー決定 1-a）

    func testReducedAccuracyAsksTemporaryFullAccuracyAndProceedsWhenGranted() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .full
        )
        let store = LocationPermissionStore(provider: provider)
        var readyActions: [LocationAction] = []
        store.onReady = { readyActions.append($0) }

        let outcome = await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(outcome, .ready(.showCurrentLocation))
        XCTAssertEqual(store.state, .allowed)
        XCTAssertEqual(readyActions, [.showCurrentLocation])
        XCTAssertNil(store.guidance)
    }

    func testDecliningTemporaryFullAccuracyFallsBackToReducedAccuracyGuidance() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .reduced
        )
        let store = LocationPermissionStore(provider: provider)
        var readyCount = 0
        store.onReady = { _ in readyCount += 1 }

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(outcome, .unavailable(.reducedAccuracy))
        XCTAssertEqual(readyCount, 0, "おおよその位置は出発地にも表示にも使わない")
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    /// 初回の OS のダイアログで「正確な位置情報」をオフにして許可した（PR #185 のレビュー）。
    func testFirstGrantWithReducedAccuracyAsksTemporaryFullAccuracy() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .full
        )
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(outcome, .ready(.showCurrentLocation))
    }

    func testFirstGrantWithReducedAccuracyDeclinedShowsGuidance() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .notDetermined),
            answer: .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .reduced
        )
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .useAsStartPoint)

        let outcome = await store.confirmExplanation()

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 1)
        XCTAssertEqual(outcome, .unavailable(.reducedAccuracy))
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    func testFullAccuracyDoesNotAskTemporaryFullAccuracy() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse), temporaryFullAccuracyAnswer: .full)
        let store = LocationPermissionStore(provider: provider)

        await store.requestLocation(for: .showCurrentLocation)

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 0)
    }

    func testRefreshDoesNotAskTemporaryFullAccuracy() async {
        let provider = StubLocationPermissionProvider(
            .init(authorization: .authorizedWhenInUse, accuracy: .reduced),
            temporaryFullAccuracyAnswer: .full
        )
        let store = LocationPermissionStore(provider: provider)

        await store.refresh()

        XCTAssertEqual(provider.temporaryFullAccuracyRequestCount, 0, "Map を開いただけでは尋ねない（決定 A）")
        XCTAssertEqual(store.state, .reducedAccuracy)
    }

    func testTemporaryUsageDescriptionIsPresentInJapanese() throws {
        let dictionary = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "NSLocationTemporaryUsageDescriptionDictionary") as? [String: String]
        )
        let text = try XCTUnwrap(dictionary[LocationAcquisitionSettings.temporaryFullAccuracyPurposeKey])
        XCTAssertTrue(text.contains("正確な位置情報"))
        XCTAssertTrue(text.contains("現在地は Nexus のサーバーへ送りません"))
    }

    // MARK: - 取得不能（#29 からの報告）

    func testAcquisitionFailureBecomesUnavailableWithRetry() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse)))
        await store.requestLocation(for: .showCurrentLocation)

        store.reportAcquisitionFailure()

        XCTAssertEqual(store.state, .unavailable)
        XCTAssertEqual(store.guidance?.actions, [.retry, .chooseStartManually])
    }

    func testRetryClearsFailureAndHandsOffToAcquisition() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse)))
        var retries = 0
        store.onRetryAcquisition = { retries += 1 }
        await store.refresh()
        store.reportAcquisitionFailure()

        store.retryAcquisition()

        XCTAssertEqual(store.state, .allowed)
        XCTAssertNil(store.guidance)
        XCTAssertEqual(retries, 1)
    }

    func testAcquisitionSuccessClearsUnavailable() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse)))
        await store.refresh()
        store.reportAcquisitionFailure()

        store.reportAcquisitionSuccess()

        XCTAssertEqual(store.state, .allowed)
        XCTAssertNil(store.guidance)
    }

    func testUnavailableStateBlocksActionUntilRetry() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse)))
        await store.refresh()
        store.reportAcquisitionFailure()

        let outcome = await store.requestLocation(for: .useAsStartPoint)

        XCTAssertEqual(outcome, .unavailable(.unavailable))
    }

    // MARK: - 設定アプリでの変更

    func testSettingsChangeFromDeniedToAllowedClearsGuidance() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .denied))
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)
        XCTAssertNotNil(store.guidance)

        provider.simulateChange(.init(authorization: .authorizedWhenInUse))

        XCTAssertEqual(store.state, .allowed)
        XCTAssertNil(store.guidance)
    }

    func testSettingsChangeToDeniedWhileDeferred() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .notDetermined))
        let store = LocationPermissionStore(provider: provider)
        await store.requestLocation(for: .showCurrentLocation)
        store.deferExplanation()

        provider.simulateChange(.init(authorization: .denied))

        XCTAssertEqual(store.state, .denied(.userDenied))
        XCTAssertEqual(store.guidance?.actions, [.openSettings, .chooseStartManually])
    }

    func testRevokingPermissionDropsOldAcquisitionFailure() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse))
        let store = LocationPermissionStore(provider: provider)
        await store.refresh()
        store.reportAcquisitionFailure()

        provider.simulateChange(.init(authorization: .denied))
        provider.simulateChange(.init(authorization: .authorizedWhenInUse))

        XCTAssertEqual(store.state, .allowed)
    }

    func testRefreshPicksUpPreciseLocationTurnedOn() async {
        let provider = StubLocationPermissionProvider(.init(authorization: .authorizedWhenInUse, accuracy: .reduced))
        let store = LocationPermissionStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.state, .reducedAccuracy)

        provider.snapshot = .init(authorization: .authorizedWhenInUse)
        await store.refresh()

        XCTAssertEqual(store.state, .allowed)
    }

    // MARK: - 出発地を自分で選ぶ（S04 への引き継ぎ）

    func testChooseStartManuallyHandsOffWithoutLocation() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .denied)))
        var manual = 0
        var ready = 0
        store.onChooseStartManually = { manual += 1 }
        store.onReady = { _ in ready += 1 }
        await store.requestLocation(for: .useAsStartPoint)

        store.chooseStartManually()

        XCTAssertEqual(manual, 1)
        XCTAssertEqual(ready, 0)
        XCTAssertNil(store.guidance)
        XCTAssertEqual(store.state, .denied(.userDenied), "手動の出発地を選んでも位置情報の状態は変えない")
    }

    func testDismissGuidanceKeepsState() async {
        let store = LocationPermissionStore(provider: StubLocationPermissionProvider(.init(authorization: .denied)))
        await store.requestLocation(for: .useAsStartPoint)

        store.dismissGuidance()

        XCTAssertNil(store.guidance)
        XCTAssertEqual(store.state, .denied(.userDenied))
    }
}

/// 状態の導出と、状態ごとの表示・操作。
final class LocationPermissionStateTests: XCTestCase {

    func testDerivePriority() {
        typealias S = LocationPermissionSnapshot
        let cases: [(S, Bool, Bool, LocationPermissionState)] = [
            (S(authorization: .notDetermined), false, false, .notAsked),
            (S(authorization: .notDetermined), true, false, .deferred),
            (S(authorization: .authorizedWhenInUse), false, false, .allowed),
            (S(authorization: .authorizedAlways), false, false, .allowed),
            (S(authorization: .authorizedWhenInUse, accuracy: .reduced), false, false, .reducedAccuracy),
            (S(authorization: .authorizedWhenInUse, accuracy: .reduced), false, true, .unavailable),
            (S(authorization: .authorizedWhenInUse), true, true, .unavailable),
            (S(authorization: .denied), true, false, .denied(.userDenied)),
            (S(authorization: .restricted), false, false, .denied(.restricted)),
            (S(authorization: .authorizedWhenInUse, servicesEnabled: false), false, true, .denied(.servicesOff)),
            (S(authorization: .notDetermined, servicesEnabled: false), true, false, .denied(.servicesOff)),
        ]
        for (snapshot, deferred, failed, expected) in cases {
            XCTAssertEqual(
                LocationPermissionState.derive(from: snapshot, deferred: deferred, acquisitionFailed: failed),
                expected,
                "\(snapshot) deferred=\(deferred) failed=\(failed)"
            )
        }
    }

    func testOnlyNotAskedAndDeferredNeedExplanation() {
        XCTAssertTrue(LocationPermissionState.notAsked.needsExplanation)
        XCTAssertTrue(LocationPermissionState.deferred.needsExplanation)
        for state in Self.nonExplainedStates {
            XCTAssertFalse(state.needsExplanation, "\(state)")
        }
    }

    /// `allowed` 以外は、必ず「出発地を自分で選ぶ」を出す。設定は変えられる状態だけ。
    func testEveryNonAllowedStateOffersManualStart() {
        XCTAssertNil(LocationPermissionGuidance(state: .allowed))
        XCTAssertNil(LocationPermissionGuidance(state: .notAsked), "まだ尋ねていないときはアプリの説明を出す")

        let expectations: [(LocationPermissionState, Bool)] = [
            (.deferred, false),
            (.denied(.userDenied), true),
            (.denied(.servicesOff), true),
            (.denied(.restricted), false),
            (.unavailable, false),
            (.reducedAccuracy, true),
        ]
        for (state, offersSettings) in expectations {
            guard let guidance = LocationPermissionGuidance(state: state) else {
                XCTFail("\(state) の表示が無い")
                continue
            }
            XCTAssertTrue(guidance.actions.contains(.chooseStartManually), "\(state)")
            XCTAssertEqual(guidance.actions.contains(.openSettings), offersSettings, "\(state)")
            XCTAssertFalse(guidance.message.title.isEmpty)
            XCTAssertNotNil(guidance.message.detail)
        }
        XCTAssertTrue(LocationPermissionGuidance(state: .unavailable)!.actions.contains(.retry))
    }

    func testStatesHaveDistinctMessages() {
        let titles = [
            LocationPermissionState.deferred, .denied(.userDenied), .denied(.servicesOff),
            .denied(.restricted), .unavailable, .reducedAccuracy,
        ].compactMap { LocationPermissionGuidance(state: $0)?.message.title }
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testCoreLocationStatusMapping() {
        XCTAssertEqual(CoreLocationPermissionProvider.authorization(from: .notDetermined), .notDetermined)
        XCTAssertEqual(CoreLocationPermissionProvider.authorization(from: .restricted), .restricted)
        XCTAssertEqual(CoreLocationPermissionProvider.authorization(from: .denied), .denied)
        XCTAssertEqual(CoreLocationPermissionProvider.authorization(from: .authorizedWhenInUse), .authorizedWhenInUse)
        XCTAssertEqual(CoreLocationPermissionProvider.authorization(from: .authorizedAlways), .authorizedAlways)
    }

    /// OS のダイアログの説明文（Info.plist）。日本語で、送信しないことを含む。
    func testWhenInUseUsageDescriptionIsPresentInJapanese() throws {
        let text = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
        )
        XCTAssertTrue(text.contains("現在地"))
        XCTAssertTrue(text.contains("送りません"))
        XCTAssertNil(
            Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription"),
            "常に許可は求めない"
        )
    }

    private static let nonExplainedStates: [LocationPermissionState] = [
        .allowed, .reducedAccuracy, .unavailable,
        .denied(.userDenied), .denied(.restricted), .denied(.servicesOff),
    ]
}

/// 権限と精度を差し込むスタブ。OS のダイアログを出した回数を数える。
@MainActor
final class StubLocationPermissionProvider: LocationPermissionProviding {
    var onChange: (@MainActor (LocationPermissionSnapshot) -> Void)?
    var snapshot: LocationPermissionSnapshot
    private let answer: LocationPermissionSnapshot?
    private let temporaryFullAccuracyAnswer: LocationAccuracy
    private(set) var requestCount = 0
    private(set) var temporaryFullAccuracyRequestCount = 0

    init(
        _ snapshot: LocationPermissionSnapshot,
        answer: LocationPermissionSnapshot? = nil,
        temporaryFullAccuracyAnswer: LocationAccuracy = .reduced
    ) {
        self.snapshot = snapshot
        self.answer = answer
        self.temporaryFullAccuracyAnswer = temporaryFullAccuracyAnswer
    }

    func requestTemporaryFullAccuracy() async -> LocationPermissionSnapshot {
        temporaryFullAccuracyRequestCount += 1
        if snapshot.accuracy == .reduced {
            snapshot = .init(
                authorization: snapshot.authorization,
                accuracy: temporaryFullAccuracyAnswer,
                servicesEnabled: snapshot.servicesEnabled
            )
        }
        return snapshot
    }

    func currentSnapshot() async -> LocationPermissionSnapshot {
        snapshot
    }

    func requestWhenInUseAuthorization() async -> LocationPermissionSnapshot {
        requestCount += 1
        if snapshot.authorization == .notDetermined, let answer {
            snapshot = answer
        }
        return snapshot
    }

    func simulateChange(_ snapshot: LocationPermissionSnapshot) {
        self.snapshot = snapshot
        onChange?(snapshot)
    }
}
