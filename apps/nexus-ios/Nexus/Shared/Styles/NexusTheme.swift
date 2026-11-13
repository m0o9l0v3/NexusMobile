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
    /// 主要カード（デザインルール「主要カード20px」。Home の開催日カード）。
    static let primaryCardCornerRadius: CGFloat = 20

    // MARK: - Color

    static let surface = Color("Surface")
    static let border = Color("NexusBorder")
    static let tintSurface = Color.accentColor.opacity(0.12)
    static let eventAccent = Color("EventAccent")
    /// アクセント色の塗りの上に置く文字・記号（選択中のチップ、「開催中」バッジ、地図のピン）。
    /// アクセント色はライト／ダークで同じなので、どちらのテーマでも白を使う。
    static let onAccent = Color.white

    /// 押下中の重ね色（State layer）。Web `--state-pressed` `rgba(11,94,215,.12)` を基に、
    /// ダークではアクセント色を明るくして見えるようにした（Asset `StatePressed` の Any / Dark）。
    static let statePressed = Color("StatePressed")

    /// カードの下地。ライトは白、ダークは背景（黒）より一段明るい灰色にして、影の代わりに浮きを示す。
    static let cardSurface = Color(.secondarySystemGroupedBackground)

    /// 「困ったとき」など注意喚起セクションの淡い下地。
    static let cautionSurface = Color.orange.opacity(0.12)
    static let cautionAccent = Color.orange
}

// MARK: - Elevation

/// Material 3 風の Elevation（3段階）。値は Web `web/src/styles/theme.css` の `--elev-1/2/3`。
///
/// - level1: 小さな面（リストの行・ボタン）。
/// - level2: 通常のカード（`nexusCard()`）。
/// - level3: 大きなカード・ヒーロー（次のイベント、開催日カード）。
///
/// CSS の blur は SwiftUI の `radius` の約2倍に当たるため、半分にして写している。
/// ダークでは背景が黒く影がほぼ見えないので、影を濃くしたうえで、カード側は一段明るい下地と枠線で浮きを示す。
enum NexusElevation: Int, CaseIterable, Sendable {
    case level1 = 1
    case level2 = 2
    case level3 = 3

    struct ShadowLayer: Equatable, Sendable {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    /// 影の層（下から順に重ねる）。色は Asset `ElevationShadow`（ライト `rgb(11,27,58)`、ダーク黒）。
    func shadowLayers(for colorScheme: ColorScheme) -> [ShadowLayer] {
        switch (self, colorScheme) {
        // --elev-1: 0 1px 2px rgba(11,27,58,.06)
        case (.level1, .dark):
            return [ShadowLayer(opacity: 0.30, radius: 1, y: 1)]
        case (.level1, _):
            return [ShadowLayer(opacity: 0.06, radius: 1, y: 1)]
        // --elev-2: 0 2px 8px rgba(11,27,58,.08), 0 1px 3px rgba(11,27,58,.06)
        case (.level2, .dark):
            return [
                ShadowLayer(opacity: 0.36, radius: 4, y: 2),
                ShadowLayer(opacity: 0.24, radius: 1.5, y: 1),
            ]
        case (.level2, _):
            return [
                ShadowLayer(opacity: 0.08, radius: 4, y: 2),
                ShadowLayer(opacity: 0.06, radius: 1.5, y: 1),
            ]
        // --elev-3: 0 4px 16px rgba(11,27,58,.10), 0 2px 6px rgba(11,27,58,.08)
        case (.level3, .dark):
            return [
                ShadowLayer(opacity: 0.44, radius: 8, y: 4),
                ShadowLayer(opacity: 0.30, radius: 3, y: 2),
            ]
        case (.level3, _):
            return [
                ShadowLayer(opacity: 0.10, radius: 8, y: 4),
                ShadowLayer(opacity: 0.08, radius: 3, y: 2),
            ]
        }
    }
}

private struct NexusElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let elevation: NexusElevation

    func body(content: Content) -> some View {
        let layers = elevation.shadowLayers(for: colorScheme)
        // 影は2層まで。層ごとに shadow を重ねる。
        content
            .shadow(
                color: Color("ElevationShadow").opacity(layers.first?.opacity ?? 0),
                radius: layers.first?.radius ?? 0,
                y: layers.first?.y ?? 0
            )
            .shadow(
                color: Color("ElevationShadow").opacity(layers.count > 1 ? layers[1].opacity : 0),
                radius: layers.count > 1 ? layers[1].radius : 0,
                y: layers.count > 1 ? layers[1].y : 0
            )
    }
}

extension View {
    /// Elevation の影を付ける。形（角丸・カプセル）を決めてから呼ぶ。
    func nexusElevation(_ elevation: NexusElevation) -> some View {
        modifier(NexusElevationModifier(elevation: elevation))
    }

    /// 角丸カード。ライトは白、ダークは一段明るい灰色。枠線と Elevation の影を付ける。
    /// 通常のカードは level2、主要カード（次のイベント・開催日カード）は
    /// `cornerRadius: NexusTheme.primaryCardCornerRadius`（20）・`elevation: .level3` にする。
    func nexusCard(
        cornerRadius: CGFloat = NexusTheme.cardCornerRadius,
        elevation: NexusElevation = .level2
    ) -> some View {
        background(NexusTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NexusTheme.border, lineWidth: 1)
            }
            .nexusElevation(elevation)
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
