import SwiftUI

struct EventSectionHeaderView: View {
    let onShowAll: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("体験イベント")
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
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityHint("体験イベント一覧への遷移要求を送ります")
        }
        .frame(minHeight: 44)
        .accessibilitySortPriority(60)
    }
}
