import SwiftUI

/// 検索結果の1行。Figma `2646:1649` 等の iOS 標準 Row（Tall・subtitle あり・区切り線）に対応。
///
/// 名称・種別・建物・階を**1つの読み上げ要素**にまとめる。分割すると VoiceOver が
/// 断片を予測できない順で読むため。
struct SearchResultRowView: View {
    let summary: SpotSummary
    let showsSeparator: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: NexusTheme.spacing12) {
                    SpotSummaryLabelView(summary: summary)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, NexusTheme.spacing12)
                .nexusTappableRow(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary.accessibilityLabelText)
            .accessibilityHint("マップで地点の詳細を開きます")
            .accessibilityAddTraits(.isButton)

            if showsSeparator {
                Divider()
                    .accessibilityHidden(true)
            }
        }
    }
}
