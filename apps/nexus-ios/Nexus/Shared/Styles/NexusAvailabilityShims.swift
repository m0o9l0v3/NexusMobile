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
