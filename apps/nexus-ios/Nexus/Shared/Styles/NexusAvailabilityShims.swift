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

    /// 地図上などに浮くパネルやカプセルの Liquid Glass 外観。
    ///
    /// iOS 26 以降は `.glassEffect`、iOS 18 は標準マテリアル・枠線・Elevation で互換表示する。
    @ViewBuilder
    func nexusFloatingGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self
                .contentShape(shape)
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(NexusTheme.border, lineWidth: 1)
                }
                .nexusElevation(.level2)
                .contentShape(shape)
        }
    }
}

/// iOS 26 の `GlassEffectContainer` の互換ラッパー。
struct NexusGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
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

/// 地図上などに浮く丸い操作ボタンのスタイル（現在地ボタンなど）。
///
/// iOS 26 以降は Liquid Glass（`.glassEffect(.regular.interactive(), in: Circle())`）を使い、
/// OS 標準の押下時の弾み・光沢・屈折とアクセシビリティ（透明度を下げる・視差効果を減らす）に委ねる。
/// iOS 18 はカード下地・枠線・Elevation と押下時の縮小アニメーションで互換表示する。
struct NexusFloatingCircleButtonStyle: PrimitiveButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        } else {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(LegacyFloatingCircleButtonStyle())
        }
    }
}

extension PrimitiveButtonStyle where Self == NexusFloatingCircleButtonStyle {
    static var nexusFloatingCircle: Self { Self() }
}

private struct LegacyFloatingCircleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(NexusTheme.cardSurface, in: Circle())
            .overlay { Circle().stroke(NexusTheme.border, lineWidth: 1) }
            .nexusElevation(.level2)
            .contentShape(Circle())
            .nexusPressFeedback(isPressed: configuration.isPressed, in: Circle())
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.90 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

// MARK: - Floating & Card Liquid Glass Controls

extension View {
    /// `NexusGlassContainer` 内の Liquid Glass 要素に識別子を付け、表示数の変化時のモーフィングを滑らかにする。
    @ViewBuilder
    func nexusGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// スクロール面や地図上に浮くカプセル・角丸バーの Liquid Glass 操作ボタンスタイル（案内のクイックジャンプバーなど）。
///
/// `AnyShape` は渡さず、具象 `Shape`（`Capsule` / `RoundedRectangle`）を型パラメータで保持する。
/// iOS 26 以降は `.glassEffect(.regular.interactive(), in: shape)` を使い、
/// iOS 18 は標準マテリアル・枠線・Elevation・押下フィードバックで互換表示する。
struct NexusFloatingGlassButtonStyle<S: Shape>: PrimitiveButtonStyle {
    let shape: S

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
                    .contentShape(shape)
                    .glassEffect(.regular.interactive(), in: shape)
            }
            .buttonStyle(.plain)
        } else {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(LegacyFloatingGlassButtonStyle(shape: shape))
        }
    }
}

extension PrimitiveButtonStyle where Self == NexusFloatingGlassButtonStyle<Capsule> {
    static var nexusFloatingCapsule: Self {
        NexusFloatingGlassButtonStyle(shape: Capsule())
    }
}

extension PrimitiveButtonStyle where Self == NexusFloatingGlassButtonStyle<RoundedRectangle> {
    static func nexusFloatingRoundedRect(cornerRadius: CGFloat) -> Self {
        NexusFloatingGlassButtonStyle(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct LegacyFloatingGlassButtonStyle<S: Shape>: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.regularMaterial, in: shape)
            .overlay {
                shape.stroke(NexusTheme.border, lineWidth: 1)
            }
            .nexusElevation(.level2)
            .contentShape(shape)
            .nexusPressFeedback(isPressed: configuration.isPressed, in: shape)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

/// 不透明カード（`cardSurface`）内に配置する副アクション用の Liquid Glass ボタンスタイル（関連地点の「場所を見る」など）。
///
/// 親カードが Liquid Glass ではない面でのみ使い、Glass on Glass を避ける。
struct NexusCardGlassButtonStyle<S: Shape>: PrimitiveButtonStyle {
    let shape: S

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
                    .contentShape(shape)
                    .glassEffect(.regular.interactive(), in: shape)
            }
            .buttonStyle(.plain)
        } else {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(LegacyCardGlassButtonStyle(shape: shape))
        }
    }
}

extension PrimitiveButtonStyle where Self == NexusCardGlassButtonStyle<Capsule> {
    static var nexusCardGlassCapsule: Self {
        NexusCardGlassButtonStyle(shape: Capsule())
    }
}

extension PrimitiveButtonStyle where Self == NexusCardGlassButtonStyle<RoundedRectangle> {
    static func nexusCardGlassRoundedRect(cornerRadius: CGFloat) -> Self {
        NexusCardGlassButtonStyle(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct LegacyCardGlassButtonStyle<S: Shape>: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(NexusTheme.tintSurface, in: shape)
            .overlay {
                shape.stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
            }
            .contentShape(shape)
            .nexusPressFeedback(isPressed: configuration.isPressed, in: shape)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

/// Liquid Glass 副ボタンと対になる主アクションボタンスタイル（関連地点の「経路を確認」など）。
///
/// ライト・ダーク双方で `AccentColor` × `OnAccent` の WCAG AA コントラスト（4.5:1 以上）を厳守しつつ、
/// 上端の光沢リムと弾성フィードバックで隣の Liquid Glass ボタンと質感を揃える。
struct NexusProminentActionButtonStyle<S: Shape>: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.accentColor, in: shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .nexusElevation(.level1)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == NexusProminentActionButtonStyle<Capsule> {
    static var nexusProminentCapsule: Self {
        NexusProminentActionButtonStyle(shape: Capsule())
    }
}

extension ButtonStyle where Self == NexusProminentActionButtonStyle<RoundedRectangle> {
    static func nexusProminentRoundedRect(cornerRadius: CGFloat) -> Self {
        NexusProminentActionButtonStyle(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
