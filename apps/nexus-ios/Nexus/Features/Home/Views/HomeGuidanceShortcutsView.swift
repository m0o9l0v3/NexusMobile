import SwiftUI

/// B. 案内ショートカット（Home v1.0 下書き、Figma `2798:1550`）。
/// 記事があるものだけを並べ、幅を分け合う。1件もなければ見出しごと出さない（呼び出し側で判定）。
struct HomeGuidanceShortcutsView: View {
    let shortcuts: [HomeGuidanceShortcut]
    let onSelect: (HomeGuidanceShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("案内")
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 16) {
                ForEach(shortcuts) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.shortcut.systemImageName)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)

                            Text(item.shortcut.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .nexusPanel()
                        .contentShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("案内の記事を開きます")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilitySortPriority(70)
    }
}
