import SwiftUI

/// 構内地図が未提供であることを明示する描画面。
///
/// Figma の Map 画面は背景に航空写真ラスタを敷いているが、これは検討用の見た目であり
/// 承認済みアセットでも正式な地図データでもない。本番地図が完成したように見せないため、
/// 画像は取り込まず、未提供であることを利用者に伝える。
/// 読み上げ対象からも外さない——地図が無いことは利用者が知るべき情報のため。
///
/// #31 の「掲載なし」（接続先はあるが未公開・地図が無い）とは別の状態として残す。こちらは接続先そのものが
/// 無いビルドで、利用者の操作や時間では変わらない（再試行は出さない）。見た目は #31 の状態の表示と同じ部品。
struct UnavailableMapSurfaceView: View {
    let context: MapSurfaceContext

    var body: some View {
        MapSurfaceStateView(
            kind: .message(MapContentStateMessage.notProvided, allowsRetry: false),
            focusedSpotID: context.focusedSpotID
        )
    }
}

#if DEBUG
#Preview("未提供") {
    UnavailableMapSurfaceView(context: .empty)
}

#Preview("地点選択中") {
    UnavailableMapSurfaceView(
        context: MapSurfaceContext(
            focusedSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
            selectedFloorID: nil
        )
    )
}
#endif
