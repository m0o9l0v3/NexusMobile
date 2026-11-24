import SwiftUI

/// Home のカテゴリチップ。文字サイズに応じて横にスクロールできる。
struct SearchCategoryPickerView: View {
    @ScaledMetric(relativeTo: .subheadline) private var chipHeight: CGFloat = 36

    let categories: [SearchCategoryID]
    let selection: SearchCategoryID?
    let onSelect: (SearchCategoryID?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NexusTheme.spacing8) {
                chip(for: nil)
                ForEach(categories) { category in
                    chip(for: category)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(for category: SearchCategoryID?) -> some View {
        let isSelected = category == selection
        return Button {
            onSelect(category)
        } label: {
            HStack(spacing: NexusTheme.spacing4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(category?.displayName ?? "すべて")
            }
            .font(.subheadline)
            .fixedSize()
            .padding(.horizontal, NexusTheme.spacing12)
            .frame(minHeight: chipHeight)
            .foregroundStyle(isSelected ? NexusTheme.onAccent : Color.primary)
            .background(isSelected ? Color.accentColor : NexusTheme.surface, in: Capsule())
            .frame(minWidth: NexusTheme.minimumTapTarget, minHeight: NexusTheme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.nexusPressableCapsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("地点を絞り込みます")
    }
}
