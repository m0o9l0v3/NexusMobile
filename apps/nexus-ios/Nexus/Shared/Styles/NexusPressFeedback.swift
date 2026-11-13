import SwiftUI
import UIKit

// MARK: - Press feedback (State layer + Ripple)

/// アプリ独自のカード・ボタンの押下表示（デザインルール「Material 3 風 State layer、Ripple」）。
///
/// - State layer: 押している間、形の上に `NexusTheme.statePressed` を重ねる。
/// - Ripple: 触れた位置から円が広がる。「視差効果を減らす」（`accessibilityReduceMotion`）では出さず、State layer だけにする。
///
/// システムの部品（`.bordered` / `.borderedProminent`、タブバー、ナビゲーションバー）には使わない。
/// タップ領域（44pt 以上）はラベル側の frame で確保する。このスタイルは大きさを変えない。
struct NexusPressableButtonStyle<S: Shape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .nexusPressFeedback(isPressed: configuration.isPressed, in: shape)
    }
}

extension ButtonStyle where Self == NexusPressableButtonStyle<RoundedRectangle> {
    /// 角丸カード・パネル用。既定はカードの角丸（16）。
    static var nexusPressable: Self { nexusPressable(cornerRadius: NexusTheme.cardCornerRadius) }

    static func nexusPressable(cornerRadius: CGFloat) -> Self {
        NexusPressableButtonStyle(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension ButtonStyle where Self == NexusPressableButtonStyle<Capsule> {
    /// カプセル形のボタン・チップ・検索欄用。
    static var nexusPressableCapsule: Self { NexusPressableButtonStyle(shape: Capsule()) }
}

extension ButtonStyle where Self == NexusPressableButtonStyle<Rectangle> {
    /// リストの行・カード内の区切られたボタン用。外側のカードの角丸で切り抜かれる前提。
    static var nexusPressableRow: Self { NexusPressableButtonStyle(shape: Rectangle()) }
}

extension ButtonStyle where Self == NexusPressableButtonStyle<Circle> {
    /// 閉じる（×）など、記号だけの丸いボタン用。
    static var nexusPressableCircle: Self { NexusPressableButtonStyle(shape: Circle()) }
}

extension View {
    /// 押下表示を重ねる。`Button` には `NexusPressableButtonStyle` を使い、これは直接呼ばない。
    func nexusPressFeedback<S: Shape>(isPressed: Bool, in shape: S) -> some View {
        modifier(NexusPressFeedbackModifier(isPressed: isPressed, shape: shape))
    }
}

private struct NexusPressFeedbackModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPressed: Bool
    let shape: S

    /// 最後に触れた位置（ウインドウの座標）。Ripple の中心にする。
    @State private var touchLocation: CGPoint?
    @State private var ripple: NexusRipple?

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    ZStack {
                        shape
                            .fill(NexusTheme.statePressed)
                            .opacity(isPressed ? 1 : 0)
                            .animation(.easeOut(duration: isPressed ? 0.08 : 0.2), value: isPressed)

                        if !reduceMotion, let ripple {
                            let frame = proxy.frame(in: .global)
                            NexusRippleView(
                                origin: ripple.origin.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) },
                                isReleased: ripple.isReleased,
                                size: proxy.size
                            )
                                .id(ripple.id)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(shape)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            // 触れた位置を記録するだけで、すぐに失敗する。Button のタップやスクロールを妨げない。
            .gesture(NexusTouchDownGesture { location in
                touchLocation = location
            })
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    ripple = NexusRipple(origin: touchLocation)
                } else {
                    ripple?.isReleased = true
                    touchLocation = nil
                }
            }
    }
}

struct NexusRipple: Equatable {
    let id = UUID()
    /// 触れた位置（ウインドウの座標）。nil のときは中心から広げる（VoiceOver・キーボード操作など）。
    let origin: CGPoint?
    var isReleased = false
}

private struct NexusRippleView: View {
    /// ラベルの座標。
    let origin: CGPoint?
    let isReleased: Bool
    let size: CGSize

    @State private var isExpanded = false

    var body: some View {
        let origin = origin ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = Self.coveringRadius(from: origin, in: size)

        Circle()
            .fill(NexusTheme.statePressed)
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(isExpanded ? 1 : 0.1)
            .position(origin)
            .opacity(isReleased ? 0 : 1)
            .animation(.easeOut(duration: 0.3), value: isReleased)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    isExpanded = true
                }
            }
    }

    /// 触れた位置から最も遠い角まで届く半径。
    static func coveringRadius(from origin: CGPoint, in size: CGSize) -> CGFloat {
        let dx = max(origin.x, size.width - origin.x)
        let dy = max(origin.y, size.height - origin.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Touch-down location

/// 指が触れた瞬間の位置（ウインドウの座標）を知らせるだけのジェスチャ。SwiftUI の `Button` は押した位置を渡さないため。
///
/// 触れた時点で位置を渡し、そのまま失敗（`.failed`）する。認識状態に入らないので、
/// ボタンのタップやスクロール（ScrollView のパン）を止めない。
private struct NexusTouchDownGesture: UIGestureRecognizerRepresentable {
    let onTouchDown: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> NexusTouchObserverGestureRecognizer {
        let recognizer = NexusTouchObserverGestureRecognizer()
        recognizer.onTouchDown = onTouchDown
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: NexusTouchObserverGestureRecognizer, context: Context) {
        recognizer.onTouchDown = onTouchDown
    }
}

final class NexusTouchObserverGestureRecognizer: UIGestureRecognizer {
    var onTouchDown: ((CGPoint) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, let touch = touches.first {
            onTouchDown?(touch.location(in: nil))
        }
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
