import Foundation

/// 取得した現在地の1点（#29）。
///
/// アプリの中だけで使う。サーバーへは送らない（Info.plist と説明シートの約束「現在地は Nexus のサーバーへ送りません」）。
struct LocationFix: Equatable, Sendable {
    let coordinate: CampusMapCoordinate
    /// 水平方向の誤差（メートル、半径）。
    let horizontalAccuracy: Double
    let timestamp: Date
}

/// 取得処理から届く知らせ。
enum LocationUpdateEvent: Equatable, Sendable {
    case fix(LocationFix)
    /// OS が一時的に位置を出せないと知らせた（屋内など）。すぐには失敗にせず、取得の待ち時間で判断する。
    case unavailable
}

/// 現在地の取得と構内判定の設定（#29）。
///
/// **すべて仮の値**。最終値は #80 の実機確認（GPS の精度・電池）で決める。値はここ1か所にまとめ、
/// 他の場所に数値を書かない。
struct LocationAcquisitionSettings: Equatable, Sendable {
    /// OS に伝える使い方（`CLLocationUpdate.LiveConfiguration`）。構内を歩いて回る使い方に合わせる。
    enum Activity: Equatable, Sendable {
        case `default`
        /// 車以外の移動の案内（徒歩の案内）。
        case otherNavigation
        case fitness
    }

    var activity: Activity
    /// 最初の1点を待つ時間。過ぎても使える点が無ければ「現在地を取得できません」にする。
    var acquisitionTimeout: Duration
    /// この誤差（メートル）より大きい点は使わない（青い点にも、取得できたことにもしない）。
    var maximumHorizontalAccuracy: Double
    /// 青い点を動かす最短の間隔。これより短い間隔で届いた点は捨てる（描き直しを減らす）。
    var minimumUpdateInterval: Duration
    /// 構内とみなす範囲を、地図の内容の範囲（建物・ピン）から外へ広げる幅（メートル）。
    /// 構内の端（門・駐車場）に立っている人や、屋外の GPS の誤差（数十メートル）で「構内から離れています」が
    /// 出ないよう、100 m にする。
    var campusMarginMeters: Double

    static let provisional = LocationAcquisitionSettings(
        activity: .otherNavigation,
        acquisitionTimeout: .seconds(15),
        maximumHorizontalAccuracy: 50,
        minimumUpdateInterval: .seconds(1),
        campusMarginMeters: 100
    )

    /// Info.plist の `NSLocationTemporaryUsageDescriptionDictionary` のキー（オーナー決定 1-a）。
    static let temporaryFullAccuracyPurposeKey = "CurrentLocation"
}

/// 現在地が構内にあるか（オーナー決定 2-a）。
enum CampusPresence: Equatable, Sendable {
    case onCampus
    case offCampus
    /// 地図の内容が無い、または現在地がまだ無い。構内かどうかを判断しない。
    case unknown

    /// - Parameter campusArea: 余白を足した構内の範囲（`CampusMapBounds.expanded(byMeters:)`）。nil なら判断しない。
    static func evaluate(_ fix: LocationFix?, in campusArea: CampusMapBounds?) -> CampusPresence {
        guard let fix, let campusArea else { return .unknown }
        return campusArea.contains(fix.coordinate) ? .onCampus : .offCampus
    }
}

/// 追従中のカメラの移動先（#29）。
enum CurrentLocationCamera {
    /// 移動後の南北の幅を、拡大表示に切り替わる幅のこの割合にする（`CampusMapFocus.zoomRatio` と同じ考え方）。
    static let zoomRatio = 0.8

    /// 現在地を中心にした表示範囲。すでにもっと寄っていればその縮尺を保つ（利用者が寄せた縮尺を勝手に戻さない）。
    /// 地図の内容が無ければ nil。
    static func region(
        centeredOn coordinate: CampusMapCoordinate,
        in content: CampusMapContent,
        visibleLatitudeDelta: Double?
    ) -> CampusMapFocus.Region? {
        guard let policy = CampusMapZoomPolicy(content: content) else { return nil }
        let target = policy.contentLatitudeSpan * CampusMapZoomPolicy.detailRatio * zoomRatio
        let latitudeDelta = min(visibleLatitudeDelta ?? target, target)
        return CampusMapFocus.Region(
            center: coordinate,
            latitudeDelta: latitudeDelta,
            // `CampusMapFocus.region` と同じく、縦長の画面で南北の幅を縮尺の基準にする。
            longitudeDelta: latitudeDelta * 0.25
        )
    }
}

/// 現在地まわりの VoiceOver の文言。View とテストが同じものを見る。
enum CurrentLocationAccessibilityText {
    static let buttonLabel = "現在地"
    static let buttonHint = "地図を現在地に合わせ、移動に合わせて動かします。"
    static let dotLabel = "現在地"
    static let offCampusTitle = "構内から離れています"
    static let offCampusDetail = "現在地の点は表示しますが、地図は構内のままにします。"

    static func buttonValue(phase: CurrentLocationStore.Phase, isFollowing: Bool) -> String {
        switch phase {
        case .locating:
            return "取得中"
        case .tracking:
            return isFollowing ? "追従中" : "追従していません"
        case .idle, .failed:
            return ""
        }
    }
}
