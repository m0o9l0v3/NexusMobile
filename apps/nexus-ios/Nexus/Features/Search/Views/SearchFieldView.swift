import SwiftUI

/// Figma `2646:1642` SearchField / Initial ・ `2672:2083` SearchField / Active / Empty。
///
/// 高さ48pt・角丸24pt・`surface` 下地。Figma のキーボード画像は実装せず、
/// システムキーボードと `@FocusState` で表現する。
struct SearchFieldView: View {
    /// 文字サイズに追従させる。固定高だと大きな文字で入力欄が窮屈になる。
    /// Home の `HomeEventCardView` と同じ `@ScaledMetric` の流儀に合わせる。
    @ScaledMetric private var fieldHeight: CGFloat = 48

    @Binding var text: String
    var placeholder: String = "学科・施設・イベントを検索"
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
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
                }
                .buttonStyle(.plain)
                .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("検索語を消去")
            }
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(minHeight: fieldHeight)
        // Figma は 48pt 高・24pt 角丸のピル形。標準文字サイズでは同じ見た目になり、
        // 文字を拡大したときは角丸を保ったまま高さだけ伸びる。
        .background(
            NexusTheme.surface,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}
