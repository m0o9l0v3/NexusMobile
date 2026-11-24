import SwiftUI

struct HomeSearchEntryView: View {
    static let prompt = "教室・施設・サービスを検索"

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(Self.prompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(NexusTheme.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(NexusTheme.border) }
            .contentShape(Capsule())
        }
        .buttonStyle(.nexusPressableCapsule)
        .nexusElevation(.level1)
        .accessibilityLabel(Self.prompt)
        .accessibilityHint("ホーム内で地点を検索します")
        .accessibilitySortPriority(90)
    }
}
