import SwiftUI

struct HomeSearchEntryView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("学科・施設・イベントを検索")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(NexusTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("学科・施設・イベントを検索")
        .accessibilityHint("検索画面への遷移要求を送ります")
        .accessibilitySortPriority(90)
    }
}
