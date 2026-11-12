import Foundation

/// 選んだ地点の強調とカメラの移動先（#28）。
///
/// 地点は `focusedSpotID` との**完全一致**だけで引く。地図上に無い ID（未掲載・置き場所が無い）では
/// 何も強調せず、カメラも動かさない。受付など別の地点や、大文字小文字だけ違う地点に置き換えない
/// （E2-5 §6 規則11）。
enum CampusMapFocus {
    /// 移動後に、選んだ地点が画面のどの高さに来るか。0.5 が中央、値を大きくすると上へ寄る。
    /// 地点詳細のカードが画面の下側を覆うため、ピンを中央より上に置く。
    static let verticalPlacement = 0.65

    /// 移動後の南北の幅を、拡大表示に切り替わる幅（`CampusMapZoomPolicy`）のこの割合にする。
    /// 拡大表示にして、選んだ地点の周りの部屋のピンと地点名も読めるようにする。
    static let zoomRatio = 0.8

    struct Region: Equatable, Sendable {
        let center: CampusMapCoordinate
        let latitudeDelta: Double
        let longitudeDelta: Double
    }

    static func pin(for focusedSpotID: CanonicalSpotID?, in content: CampusMapContent) -> CampusMapContent.Pin? {
        guard let focusedSpotID else { return nil }
        return content.pins.first { $0.spotID == focusedSpotID }
    }

    /// 選んだ地点が所在する建物。地図上に無い建物の ID は返さない。
    static func highlightedBuildingID(for focusedSpotID: CanonicalSpotID?, in content: CampusMapContent) -> String? {
        guard let buildingID = pin(for: focusedSpotID, in: content)?.buildingID,
              content.buildings.contains(where: { $0.id == buildingID })
        else {
            return nil
        }
        return buildingID
    }

    /// 選んだ地点へのカメラの移動先。地図上に無い地点では nil（カメラを動かさない）。
    ///
    /// すでに拡大表示でもっと寄っていれば、その縮尺を保つ（利用者が寄せた縮尺を勝手に戻さない）。
    static func region(
        for focusedSpotID: CanonicalSpotID?,
        in content: CampusMapContent,
        visibleLatitudeDelta: Double?
    ) -> Region? {
        guard let pin = pin(for: focusedSpotID, in: content),
              let policy = CampusMapZoomPolicy(content: content)
        else {
            return nil
        }
        let target = policy.contentLatitudeSpan * CampusMapZoomPolicy.detailRatio * zoomRatio
        let latitudeDelta = min(visibleLatitudeDelta ?? target, target)
        // ピンを中央より上に置くため、中心を南へずらす。
        let centerLatitude = pin.coordinate.latitude - latitudeDelta * (verticalPlacement - 0.5)
        return Region(
            center: CampusMapCoordinate(latitude: centerLatitude, longitude: pin.coordinate.longitude),
            latitudeDelta: latitudeDelta,
            // MapKit は両方の幅が収まる縮尺にする。縦長の画面で南北の幅を縮尺の基準にするため、
            // 東西の幅は小さく渡す（東西は画面の幅だけ自然に広がる）。
            longitudeDelta: latitudeDelta * 0.25
        )
    }
}
