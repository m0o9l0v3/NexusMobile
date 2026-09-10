import SwiftUI

/// 構内地図が未提供であることを明示する描画面。
///
/// Figma の Map 画面は背景に航空写真ラスタを敷いているが、これは検討用の見た目であり
/// 承認済みアセットでも正式な地図データでもない。本番地図が完成したように見せないため、
/// 画像は取り込まず、未提供であることを利用者に伝える。
/// 読み上げ対象からも外さない——地図が無いことは利用者が知るべき情報のため。
struct UnavailableMapSurfaceView: View {
    let context: MapSurfaceContext

    var body: some View {
        ZStack {
            NexusTheme.surface

            VStack(spacing: NexusTheme.spacing12) {
                Image(systemName: "map")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("構内地図は未提供です")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("地図データの接続後に、建物・階と地点を表示します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let focusedSpotID = context.focusedSpotID {
                    Text("選択中の地点ID：\(focusedSpotID.rawValue)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.top, NexusTheme.spacing4)
                }
            }
            .padding(NexusTheme.spacing20)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("未提供") {
    UnavailableMapSurfaceView(context: .empty)
}

#Preview("地点選択中") {
    UnavailableMapSurfaceView(
        context: MapSurfaceContext(
            focusedSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
            selectedFloorID: nil
        )
    )
}
#endif
