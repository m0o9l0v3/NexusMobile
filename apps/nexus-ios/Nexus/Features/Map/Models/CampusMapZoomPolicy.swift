import Foundation

/// 構内地図のズームに応じた表示の出し分け（#26）。
///
/// 構内全体を見ている間は、教室のピンを出さない。80件を超える教室のピンと名前が重なって、
/// 建物のラベルが読めなくなるのを防ぐため。建物のピンの地点名は、同じ位置に同じ名前の
/// 建物のラベルが描かれるときだけ省く（ラベルが無い・名前が違うときは省かない）。
/// 拡大すると、すべてのピンと地点名を出す。
///
/// 選択中の地点は、どの縮尺でもピンと地点名を出す（選んだ地点が地図から消えないように）。
/// 表示しないピンは読み上げにも出さない。ピンの読み上げの名前は、地点名の表示の有無にかかわらず付ける。
///
/// 閾値は構内の大きさに対する割合で決める。固定の度数にすると、データの範囲が変わったときに
/// 最初の表示（構内全体）がどちらの段階になるかが変わってしまうため。
struct CampusMapZoomPolicy: Equatable, Sendable {
    /// 建物とピンをすべて収める範囲の南北の幅（度）。
    let contentLatitudeSpan: Double

    /// 表示中の南北の幅が、構内の南北の幅のこの割合以下になったら拡大表示とする。
    /// 最初の表示は構内の幅の 1.25 倍（`MapKitMapSurfaceView.initialPosition`）なので、
    /// 2倍強に拡大した時点で切り替わる。
    static let detailRatio = 0.6

    /// 構内の幅がこれより小さくても、この幅（約55m）を構内の幅とみなす。
    /// 建物1棟だけのデータで、ほとんど拡大しないと地点名が出ない状態を避ける。
    static let minimumContentLatitudeSpan = 0.0005

    init(contentLatitudeSpan: Double) {
        self.contentLatitudeSpan = max(contentLatitudeSpan, Self.minimumContentLatitudeSpan)
    }

    /// 範囲を持たない（建物もピンもない）内容では nil。
    init?(content: CampusMapContent) {
        guard let bounds = content.bounds else { return nil }
        self.init(contentLatitudeSpan: bounds.maxLatitude - bounds.minLatitude)
    }

    enum Level: Equatable, Sendable {
        /// 構内全体。
        case overview
        /// 拡大。すべてのピンと地点名を出す。
        case detail
    }

    /// 寄れる限り（`CampusMapCameraPolicy.minimumDistance`）のこの倍率以内まで寄ったら、構内の大きさに
    /// かかわらず拡大表示とする。寄れる距離の下限（改訂4 §6）のため、構内が小さいと `detailRatio` の幅まで
    /// 寄れず、部屋のピンが出ない状態を避ける。
    static let detailDistanceRatio = 1.2

    func level(visibleLatitudeDelta: Double, cameraDistance: Double? = nil) -> Level {
        if let cameraDistance,
           cameraDistance <= CampusMapCameraPolicy.minimumDistance * Self.detailDistanceRatio {
            return .detail
        }
        return visibleLatitudeDelta <= contentLatitudeSpan * Self.detailRatio ? .detail : .overview
    }

    static func showsPin(_ pin: CampusMapContent.Pin, at level: Level, focusedSpotID: CanonicalSpotID?) -> Bool {
        if pin.spotID == focusedSpotID { return true }
        switch level {
        case .detail:
            return true
        case .overview:
            return pin.appearance != .classroom
        }
    }

    static func showsPinName(_ pin: CampusMapContent.Pin, at level: Level, focusedSpotID: CanonicalSpotID?) -> Bool {
        if pin.spotID == focusedSpotID { return true }
        switch level {
        case .detail:
            return true
        case .overview:
            // 同じ位置・同じ名前の建物のラベルがあれば、地点名はそれで読める。
            return !pin.isNamedByBuildingLabel
        }
    }
}
