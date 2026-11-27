import SwiftUI

struct HomeSearchEntryView: View {
    static let prompt = "教室・施設・サービスを検索"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let action: () -> Void

    private var containerShape: AnyShape {
        dynamicTypeSize.isAccessibilitySize
            ? AnyShape(RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous))
            : AnyShape(Capsule())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .frame(minWidth: 24, minHeight: 24)
                    .accessibilityHidden(true)

                Text(Self.prompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(NexusTheme.surface, in: containerShape)
            .overlay { containerShape.stroke(NexusTheme.border, lineWidth: 1) }
            .contentShape(containerShape)
        }
        .buttonStyle(NexusPressableButtonStyle(shape: containerShape))
        .nexusElevation(.level1)
        .accessibilityLabel(Self.prompt)
        .accessibilityHint("ホーム内で地点を検索します")
        .accessibilitySortPriority(90)
    }
}
