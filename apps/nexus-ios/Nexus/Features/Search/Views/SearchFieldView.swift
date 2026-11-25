import SwiftUI

/// Figma `2646:1642` SearchField / Initial ・ `2672:2083` SearchField / Active / Empty。
///
/// 高さ48pt・角丸24pt・`surface` 下地。Figma のキーボード画像は実装せず、
/// システムキーボードと `@FocusState` で表現する。
struct SearchFieldView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let mapMinHeight: CGFloat = 48
    private static let homeMinHeight: CGFloat = 56

    @Binding var text: String
    var surface: SearchSurface = .map
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    private var placeholder: String {
        surface == .home ? HomeSearchEntryView.prompt : "学科・施設・イベントを検索"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(dynamicTypeSize.isAccessibilitySize ? "検索" : placeholder, text: $text)
                .font(.body)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .accessibilityLabel("検索語の入力")

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索語を消去")
            }
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(minHeight: surface == .home ? Self.homeMinHeight : Self.mapMinHeight)
        .background {
            if surface == .home {
                Capsule().fill(NexusTheme.surface)
                    .overlay { Capsule().strokeBorder(NexusTheme.border) }
                    .nexusElevation(.level1)
            } else {
                RoundedRectangle(cornerRadius: 24).fill(NexusTheme.surface)
            }
        }
    }
}
