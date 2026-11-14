import SwiftUI

/// iOS 26 固有の外観をここに閉じ込める唯一のファイル。
///
/// Figma は iOS 26 の Liquid Glass 外観で描かれているが、Deployment Target は iOS 18.0。
/// iOS 26 専用 API を無条件で使わず、iOS 18 では標準マテリアルで互換表示する。
/// 標準コントロール（TabView / ツールバー / Picker）は OS 側が外観を出すので、
/// **独自の blur や glass を二重適用しない**。ここで扱うのは自前パネルだけ。
extension View {
    /// 浮いているパネル（Map の検索オーバーレイなど）の下地。
    @ViewBuilder
    func nexusFloatingSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26, *) {
            self
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.30), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(NexusTheme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        }
    }
}

extension DynamicTypeSize {
    /// セグメント表示を縦積みへ切り替える閾値。
    var prefersVerticalControls: Bool { isAccessibilitySize }
}

/// タブバーから伸びる下のシート（現在地の理由の表示）の形。
///
/// 左右と下を `NexusTheme.attachedSheetMargin` 空けた浮いた面で、上の角は 28、下の角は画面の角に沿う。
/// Figma「v1.0 | 現在地UI 下部バー連結 案｜2026-11」の案B（`2812:1710`）。
/// iOS 26 は `ConcentricRectangle` で画面の角と同心にする。iOS 18 は下の角を固定値にする
/// （iOS 18 のタブバーは画面幅いっぱいで不透明なので、下の角はバーに隠れる）。
struct NexusAttachedSheetBackground: View {
    var body: some View {
        let shape = Self.shape
        shape
            .fill(NexusTheme.cardSurface)
            .overlay { shape.stroke(NexusTheme.border, lineWidth: 1) }
            .nexusElevation(.level2)
    }

    static var shape: AnyShape {
        let top = NexusTheme.attachedSheetTopCornerRadius
        if #available(iOS 26, *) {
            return AnyShape(ConcentricRectangle(
                topLeadingCorner: .fixed(top),
                topTrailingCorner: .fixed(top),
                bottomLeadingCorner: .concentric(minimum: .fixed(top)),
                bottomTrailingCorner: .concentric(minimum: .fixed(top))
            ))
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: top, style: .continuous))
        }
    }
}
