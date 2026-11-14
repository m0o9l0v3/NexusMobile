import SwiftUI

struct EventSectionHeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onShowAll: () -> Void

    var body: some View {
        // 大きな文字サイズでは見出しと「すべて見る」を横に並べると見出しが細切れに折り返すため、縦に積む（#78）。
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            // 並べ方（開始の早い順）が分かる見出しにする（E2-5 改訂1 EV-D3）。
            Text("この後のイベント")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onShowAll) {
                HStack(spacing: 4) {
                    Text("すべて見る")
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .frame(minHeight: NexusTheme.minimumTapTarget)
                .contentShape(Capsule())
            }
            .buttonStyle(.nexusPressableCapsule)
            // 押下表示のための左右の余白で、文字の端（横並びは右端、縦積みは左端）がずれないようにする。
            .padding(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, -8)
            .foregroundStyle(Color.accentColor)
            .accessibilityHint("イベント一覧への遷移要求を送ります")
        }
        .frame(minHeight: 44)
        .accessibilitySortPriority(60)
    }
}
