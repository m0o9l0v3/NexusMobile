import SwiftUI

/// Figma の Variables（`space/*`, `radius/*`, `label`, `secondary`, `surface`, `tint`）に対応するトークン。
/// 値は Figma `get_variable_defs` で確認したもの。色は Asset Catalog の名前付き色か
/// semantic color を使い、ライト／ダーク双方へ追従させる。
enum NexusTheme {
    // MARK: - Spacing (Figma space/*)

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20

    static let contentPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20

    /// Human Interface Guidelines の最小タップ領域。
    static let minimumTapTarget: CGFloat = 44

    // MARK: - Radius (Figma radius/*)

    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 12

    // MARK: - Color

    static let surface = Color("Surface")
    static let border = Color("NexusBorder")
    static let tintSurface = Color.accentColor.opacity(0.12)
    static let eventAccent = Color(red: 1, green: 141 / 255, blue: 40 / 255)
    static let cardShadow = Color.black.opacity(0.07)

    /// 「困ったとき」など注意喚起セクションの淡い下地。
    static let cautionSurface = Color.orange.opacity(0.12)
    static let cautionAccent = Color.orange
}

extension View {
    func nexusCard() -> some View {
        background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                    .stroke(NexusTheme.border, lineWidth: 1)
            }
            .shadow(color: NexusTheme.cardShadow, radius: 5, y: 2)
    }

    /// 塗りだけの角丸パネル（影・枠線なし）。案内の記事セクション等で使う。
    func nexusPanel(
        _ fill: Color = NexusTheme.surface,
        cornerRadius: CGFloat = NexusTheme.cardCornerRadius
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// タップ領域を 44pt 以上に保ちつつ、領域全体をヒットテスト対象にする。
    func nexusTappableRow(minHeight: CGFloat = NexusTheme.minimumTapTarget) -> some View {
        frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}
