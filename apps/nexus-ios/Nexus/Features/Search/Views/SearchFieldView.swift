import SwiftUI

/// Figma `2646:1642` SearchField / Initial ・ `2672:2083` SearchField / Active / Empty。
///
/// Home は高さ 56pt の `surface` カプセル、Map は高さ 52pt で外側の単一枠 Liquid Glass パネルに載せる。
/// Figma のキーボード画像は実装せず、システムキーボードと `@FocusState` で表現する。
struct SearchFieldView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let mapMinHeight: CGFloat = 52
    private static let homeMinHeight: CGFloat = 56

    @Binding var text: String
    var surface: SearchSurface = .map
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void
    var onClose: (() -> Void)? = nil

    private var placeholder: String {
        surface == .home ? HomeSearchEntryView.prompt : "学科・施設・イベントを検索"
    }

    var body: some View {
        if surface == .home {
            fieldRow
                .padding(.horizontal, NexusTheme.spacing16)
                .padding(.vertical, NexusTheme.spacing8)
                .frame(minHeight: Self.homeMinHeight)
                .background {
                    Capsule().fill(NexusTheme.surface)
                        .overlay { Capsule().strokeBorder(NexusTheme.border) }
                        .nexusElevation(.level1)
                }
        } else {
            fieldRow
                .padding(.leading, NexusTheme.spacing16)
                .padding(.trailing, text.isEmpty && onClose == nil ? NexusTheme.spacing16 : NexusTheme.spacing4)
                .padding(.vertical, NexusTheme.spacing4)
                .frame(minHeight: Self.mapMinHeight)
        }
    }

    private var fieldRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                .onTapGesture {
                    isFocused = true
                }

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

            if let onClose {
                if !text.isEmpty {
                    Divider().frame(height: 24)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索を閉じる")
            }
        }
    }
}
