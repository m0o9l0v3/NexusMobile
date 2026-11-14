import Foundation

/// OS が返す位置情報の権限（Core Location の `CLAuthorizationStatus` をアプリ側の型に写したもの）。
///
/// アプリが求めるのは「使用中のみ（When In Use）」だけ。`always` は求めないが、
/// 端末側で付いている場合も使える状態として扱う。
enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
}

/// 位置の精度（`CLAccuracyAuthorization`）。「正確な位置情報」がオフなら `reduced`。
enum LocationAccuracy: Equatable, Sendable {
    case full
    case reduced
}

/// ある時点の、端末の位置情報の設定。
struct LocationPermissionSnapshot: Equatable, Sendable {
    let authorization: LocationAuthorization
    let accuracy: LocationAccuracy
    /// 端末全体の「位置情報サービス」。オフのとき OS は権限を `denied` と返すので、別に持って区別する。
    let servicesEnabled: Bool

    init(
        authorization: LocationAuthorization,
        accuracy: LocationAccuracy = .full,
        servicesEnabled: Bool = true
    ) {
        self.authorization = authorization
        self.accuracy = accuracy
        self.servicesEnabled = servicesEnabled
    }
}

/// 位置情報が使えない理由のうち、OS の設定によるもの。
enum LocationDenialReason: Equatable, Sendable {
    /// 利用者が Nexus の位置情報を許可していない。設定で変えられる。
    case userDenied
    /// 機能制限（スクリーンタイム・管理端末など）。利用者が設定で変えられないことがある。
    case restricted
    /// 端末全体の「位置情報サービス」がオフ。
    case servicesOff
}

/// アプリが区別する位置情報の状態（#25）。
///
/// どの状態でも架空の現在地は置かない。`allowed` 以外では、出発地を自分で選ぶ道（S04）を案内する。
enum LocationPermissionState: Equatable, Sendable {
    /// まだ一度も尋ねていない（OS は `notDetermined`）。
    case notAsked
    /// アプリの説明で「後で」を選んだ。OS のダイアログはまだ出していない。
    /// 次に現在地を使う操作をしたとき、もう一度アプリの説明から始める（2026-11-14 オーナー決定 X）。
    case deferred
    /// 使用中の位置情報が使え、精度も正確。
    case allowed
    /// 許可されているが「正確な位置情報」がオフ。出発地には使わない。
    case reducedAccuracy
    /// 拒否・機能制限・位置情報サービスがオフ。
    case denied(LocationDenialReason)
    /// 許可されているが、現在地を取得できなかった（#29 の取得処理が報告する）。
    case unavailable

    /// OS の設定・「後で」の選択・取得の失敗から状態を決める。
    ///
    /// 優先順位：位置情報サービス → OS の権限 → 取得の失敗 → 精度。
    static func derive(
        from snapshot: LocationPermissionSnapshot,
        deferred: Bool,
        acquisitionFailed: Bool
    ) -> LocationPermissionState {
        guard snapshot.servicesEnabled else {
            return .denied(.servicesOff)
        }
        switch snapshot.authorization {
        case .notDetermined:
            return deferred ? .deferred : .notAsked
        case .restricted:
            return .denied(.restricted)
        case .denied:
            return .denied(.userDenied)
        case .authorizedWhenInUse, .authorizedAlways:
            if acquisitionFailed {
                return .unavailable
            }
            return snapshot.accuracy == .reduced ? .reducedAccuracy : .allowed
        }
    }

    /// 現在地を使う操作をしたとき、まずアプリの説明を出すか（OS がまだ尋ねられる状態）。
    var needsExplanation: Bool {
        switch self {
        case .notAsked, .deferred:
            return true
        case .allowed, .reducedAccuracy, .denied, .unavailable:
            return false
        }
    }
}

/// 現在地を使いたい操作の種類。許可されたあと、どこへ引き継ぐかを決める。
enum LocationAction: Equatable, Sendable {
    /// 地図で現在地を表示する（取得・青い点・追従は #29）。
    case showCurrentLocation
    /// 経路の出発地に現在地を使う（経路の作業、S04 / S05）。
    case useAsStartPoint
}

/// 状態ごとの表示と、次に取れる操作。View とテストが同じものを見る。
struct LocationPermissionGuidance: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// 設定アプリの Nexus のページを開く。
        case openSettings
        /// 現在地の取得をやり直す（#29 へ渡す）。
        case retry
        /// 出発地を自分で選ぶ（S04 へ渡す）。
        case chooseStartManually
    }

    let message: NexusStateMessage
    /// 上から順に並べる。先頭が主な操作。
    let actions: [Action]

    /// 使える状態（`allowed`）と、まだ尋ねていない状態（説明を出す）では nil。
    init?(state: LocationPermissionState) {
        switch state {
        case .notAsked, .allowed:
            return nil
        case .deferred:
            message = NexusStateMessage(
                title: "現在地は使っていません",
                detail: "出発地を自分で選んで進めます。現在地を使うときは、もう一度確認します。",
                systemImageName: "location.slash"
            )
            actions = [.chooseStartManually]
        case .denied(.userDenied):
            message = NexusStateMessage(
                title: "位置情報が許可されていません",
                detail: "現在地を使うには、設定で Nexus の位置情報を「このAppの使用中」にしてください。出発地は自分で選んで進められます。",
                systemImageName: "location.slash"
            )
            actions = [.openSettings, .chooseStartManually]
        case .denied(.servicesOff):
            message = NexusStateMessage(
                title: "位置情報サービスがオフです",
                detail: "現在地を使うには、設定の「プライバシーとセキュリティ」→「位置情報サービス」をオンにしてください。出発地は自分で選んで進められます。",
                systemImageName: "location.slash"
            )
            actions = [.openSettings, .chooseStartManually]
        case .denied(.restricted):
            message = NexusStateMessage(
                title: "この端末では位置情報を使えません",
                detail: "機能制限などで位置情報の利用が制限されています。出発地を自分で選んで進めてください。",
                systemImageName: "location.slash"
            )
            actions = [.chooseStartManually]
        case .unavailable:
            message = NexusStateMessage(
                title: "現在地を取得できません",
                detail: "屋内や建物の近くでは取得できないことがあります。もう一度試すか、出発地を自分で選んでください。",
                systemImageName: "exclamationmark.circle"
            )
            actions = [.retry, .chooseStartManually]
        case .reducedAccuracy:
            message = NexusStateMessage(
                title: "位置の精度が足りません",
                detail: "おおよその位置は出発地に使いません。設定で「正確な位置情報」をオンにするか、出発地を自分で選んでください。",
                systemImageName: "scope"
            )
            actions = [.openSettings, .chooseStartManually]
        }
    }
}
