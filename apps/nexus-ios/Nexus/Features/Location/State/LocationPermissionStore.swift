import Foundation

/// 現在地を使う操作の結果。
enum LocationActionOutcome: Equatable, Sendable {
    /// 使える。#29（現在地の表示）や経路の作業（出発地）へ引き継ぐ。
    case ready(LocationAction)
    /// アプリの説明を出した。利用者の答えを待つ。
    case explanationPresented
    /// 使えない。`guidance` に理由と次の操作がある。架空の現在地は置かない。
    case unavailable(LocationPermissionState)
}

/// 位置情報の権限フロー（#25）。
///
/// - アプリ起動時・Map を開いたときには説明を出さない。現在地を使う操作（`requestLocation(for:)`）が
///   最初の入口（2026-11-14 オーナー決定 A）。
/// - 「後で」では OS のダイアログを出さない。次の操作でもう一度アプリの説明を出す（オーナー決定 X）。
/// - OS のダイアログは「位置情報を使う」を押したときだけ出す。
@MainActor
@Observable
final class LocationPermissionStore {
    private(set) var state: LocationPermissionState = .notAsked
    /// アプリの説明（OS のダイアログの前の画面）を出しているか。
    private(set) var isExplanationPresented = false
    /// 説明を出すきっかけになった操作。許可されたらこの操作として引き継ぐ。
    private(set) var pendingAction: LocationAction?
    /// 使えなかったときに表示する理由と次の操作。閉じると nil。
    private(set) var guidance: LocationPermissionGuidance?
    private(set) var isRequestingAuthorization = false

    @ObservationIgnored private let provider: LocationPermissionProviding
    @ObservationIgnored private var snapshot: LocationPermissionSnapshot?
    @ObservationIgnored private var deferred = false
    @ObservationIgnored private var acquisitionFailed = false

    /// 使える状態になった操作の引き継ぎ先（#29・経路の作業）。
    @ObservationIgnored var onReady: (@MainActor (LocationAction) -> Void)?
    /// 「出発地を自分で選ぶ」の引き継ぎ先（S04）。現在地の代わりの値は渡さない。
    @ObservationIgnored var onChooseStartManually: (@MainActor () -> Void)?
    /// 「もう一度試す」の引き継ぎ先（#29 の取得処理）。
    @ObservationIgnored var onRetryAcquisition: (@MainActor () -> Void)?

    init(provider: LocationPermissionProviding) {
        self.provider = provider
        provider.onChange = { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    /// いまの設定を読む。OS のダイアログも、アプリの説明も出さない。
    func refresh() async {
        apply(await provider.currentSnapshot())
    }

    /// 現在地を使う操作をした。
    @discardableResult
    func requestLocation(for action: LocationAction) async -> LocationActionOutcome {
        if snapshot == nil {
            await refresh()
        }
        if state.needsExplanation {
            pendingAction = action
            guidance = nil
            isExplanationPresented = true
            return .explanationPresented
        }
        return finish(action)
    }

    /// アプリの説明で「位置情報を使う」を押した。ここで初めて OS のダイアログを出す。
    @discardableResult
    func confirmExplanation() async -> LocationActionOutcome? {
        guard isExplanationPresented, !isRequestingAuthorization else { return nil }
        let action = pendingAction ?? .showCurrentLocation
        isExplanationPresented = false
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        deferred = false
        apply(await provider.requestWhenInUseAuthorization())
        pendingAction = nil

        if state == .notAsked {
            // OS が答えを返さなかった。次の操作でまた説明から始める。
            return nil
        }
        return finish(action)
    }

    /// アプリの説明で「後で」を押した。OS のダイアログは出さない。
    func deferExplanation() {
        guard isExplanationPresented else { return }
        isExplanationPresented = false
        pendingAction = nil
        deferred = true
        recompute()
        guidance = LocationPermissionGuidance(state: state)
    }

    /// 理由の表示を閉じた。
    func dismissGuidance() {
        guidance = nil
    }

    /// 「出発地を自分で選ぶ」。S04 へ引き継ぐ。
    func chooseStartManually() {
        guidance = nil
        isExplanationPresented = false
        pendingAction = nil
        onChooseStartManually?()
    }

    /// 「もう一度試す」。失敗の記録を消して #29 の取得へ戻す。
    func retryAcquisition() {
        acquisitionFailed = false
        recompute()
        guidance = nil
        onRetryAcquisition?()
    }

    // MARK: - #29 からの報告

    /// 許可はあるが現在地を取得できなかった（#29 が呼ぶ）。
    func reportAcquisitionFailure() {
        acquisitionFailed = true
        recompute()
        guidance = LocationPermissionGuidance(state: state)
    }

    /// 現在地を取得できた（#29 が呼ぶ）。取得失敗の表示を消す。
    func reportAcquisitionSuccess() {
        guard acquisitionFailed else { return }
        acquisitionFailed = false
        recompute()
        guidance = nil
    }

    // MARK: - Private

    private func finish(_ action: LocationAction) -> LocationActionOutcome {
        if state == .allowed {
            guidance = nil
            onReady?(action)
            return .ready(action)
        }
        guidance = LocationPermissionGuidance(state: state)
        return .unavailable(state)
    }

    private func apply(_ snapshot: LocationPermissionSnapshot) {
        // 権限が外れたら、以前の取得失敗は意味を失う。
        if snapshot.authorization != .authorizedWhenInUse, snapshot.authorization != .authorizedAlways {
            acquisitionFailed = false
        }
        self.snapshot = snapshot
        let previous = state
        recompute()
        // 設定アプリで許可されたら、出していた理由の表示を閉じる。
        if previous != state, guidance != nil {
            guidance = LocationPermissionGuidance(state: state)
        }
    }

    private func recompute() {
        guard let snapshot else { return }
        state = LocationPermissionState.derive(
            from: snapshot,
            deferred: deferred,
            acquisitionFailed: acquisitionFailed
        )
    }
}
