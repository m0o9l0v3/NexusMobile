import Foundation

/// Map 上で選択されている地点。
///
/// タブ切替で失われてはならない状態なので、`NavigationPath` ではなく `MapStore` が持つ。
/// Figma `2639:1550` でも地点詳細は地図上のカードとして描かれている。
struct MapSelection: Equatable, Sendable {
    let canonicalSpotID: CanonicalSpotID
    /// 展示・イベントから来た場合の展示ID。同じ地点の別展示を区別するために捨てない。
    let eventID: String?
    /// どのタブから選択されたか。
    let origin: AppTab
}

enum SpotDetailFetchResult: Equatable, Sendable {
    case fresh(SpotDetailPresentation)
    case saved(SpotDetailPresentation, NexusSavedMetadata)
    /// 公開データに存在しない canonical ID。受付など別地点へ置換しない。
    case unknownSpot(CanonicalSpotID)
}

enum MapSpotDetailState: Equatable, Sendable {
    case none
    case loading(CanonicalSpotID)
    case loaded(SpotDetailPresentation)
    case saved(SpotDetailPresentation, NexusSavedMetadata)
    case unknown(CanonicalSpotID)
    case failed(CanonicalSpotID, NexusStateMessage)
}

/// 地図描画面へ渡す文脈。座標は含めない（実地図の採用は #85 の判断）。
struct MapSurfaceContext: Equatable, Sendable {
    let focusedSpotID: CanonicalSpotID?
    let selectedFloorID: String?

    static let empty = MapSurfaceContext(focusedSpotID: nil, selectedFloorID: nil)
}
