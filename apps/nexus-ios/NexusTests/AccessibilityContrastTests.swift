import UIKit
import XCTest
@testable import Nexus

/// アプリ独自の色の組み合わせが WCAG AA を満たすか（#78、`docs/verification/ios-a11y-check.md` の観点4）。
///
/// Asset Catalog の Any / Dark とシステムの色をライト・ダークそれぞれで解決し、比を計算する。
/// 半透明の下地（`tintSurface` など）は、その下の面に重ねた色で比べる。
/// 本文の文字は 4.5:1、大きな文字と UI 部品は 3:1 を基準にする。
final class AccessibilityContrastTests: XCTestCase {
    private static let textMinimum = 4.5

    // MARK: - Colors

    private static func asset(_ name: String) -> UIColor {
        guard let color = UIColor(named: name, in: Bundle.main, compatibleWith: nil) else {
            fatalError("Asset \(name) がありません")
        }
        return color
    }

    private static var accent: UIColor { asset("AccentColor") }
    private static var onAccent: UIColor { asset("OnAccent") }
    private static var cancelled: UIColor { asset("Cancelled") }
    private static var caution: UIColor { asset("CautionAccent") }
    private static var surface: UIColor { asset("Surface") }
    private static let background = UIColor.systemBackground
    private static let cardSurface = UIColor.secondarySystemGroupedBackground

    /// 文字を置く下地。半透明の重ね色は (色, 不透明度, その下の面) で表す。
    private enum Backdrop: CustomStringConvertible {
        case solid(String, UIColor)
        case overlay(String, UIColor, CGFloat, over: UIColor)

        var description: String {
            switch self {
            case .solid(let name, _), .overlay(let name, _, _, _): return name
            }
        }

        func resolved(in traits: UITraitCollection) -> RGB {
            switch self {
            case .solid(_, let color):
                return RGB(color.resolvedColor(with: traits))
            case .overlay(_, let color, let alpha, let base):
                return RGB(color.resolvedColor(with: traits))
                    .blended(alpha: alpha, over: RGB(base.resolvedColor(with: traits)))
            }
        }
    }

    private static var accentBackdrops: [Backdrop] {
        [
            .solid("systemBackground", background),
            .solid("cardSurface", cardSurface),
            .solid("Surface", surface),
            .overlay("tintSurface/cardSurface", accent, 0.12, over: cardSurface),
            .overlay("tintSurface/Surface", accent, 0.12, over: surface),
            .overlay("tintSurface/systemBackground", accent, 0.12, over: background),
        ]
    }

    // MARK: - Tests

    /// カテゴリ名・「詳細」「マップで見る」「すべて見る」・案内の見出しなど、アクセント色の文字。
    func testAccentTextMeetsAA() {
        assertContrast(foreground: Self.accent, name: "AccentColor", on: Self.accentBackdrops)
    }

    /// 選択中のチップ・「開催中」バッジ・主ボタン（borderedProminent）の文字。
    func testOnAccentTextOnAccentFillMeetsAA() {
        assertContrast(foreground: Self.onAccent, name: "OnAccent", on: [.solid("AccentColor", Self.accent)])
    }

    /// 中止の文字（イベントカード・一覧の行・地点詳細の枠・開催日カード）。
    func testCancelledTextMeetsAA() {
        assertContrast(
            foreground: Self.cancelled,
            name: "Cancelled",
            on: [
                .solid("systemBackground", Self.background),
                .solid("cardSurface", Self.cardSurface),
                .overlay("cancelled 8%/cardSurface", Self.cancelled, 0.08, over: Self.cardSurface),
                .overlay("tintSurface/cardSurface", Self.accent, 0.12, over: Self.cardSurface),
                .overlay("tintSurface/systemBackground", Self.accent, 0.12, over: Self.background),
            ]
        )
    }

    /// 開催日カードの「中止」バッジ。
    func testOnAccentTextOnCancelledBadgeMeetsAA() {
        assertContrast(foreground: Self.onAccent, name: "OnAccent", on: [.solid("Cancelled", Self.cancelled)])
    }

    /// 案内の「困ったとき」の見出しと記号。
    func testCautionTextMeetsAA() {
        assertContrast(
            foreground: Self.caution,
            name: "CautionAccent",
            on: [
                .solid("systemBackground", Self.background),
                .solid("cardSurface", Self.cardSurface),
                .overlay("cautionSurface/cardSurface", UIColor.systemOrange, 0.12, over: Self.cardSurface),
                .overlay("cautionSurface/systemBackground", UIColor.systemOrange, 0.12, over: Self.background),
            ]
        )
    }

    /// 位置情報の説明シート（#25）。シートの下地はダークで一段明るい（elevated）systemBackground になる。
    /// アイコン・「後で」ボタンの文字（アクセント色）と、主ボタンの文字（OnAccent）。
    func testLocationPermissionSheetMeetsAA() {
        assertContrast(
            foreground: Self.accent,
            name: "AccentColor",
            on: [
                .solid("systemBackground (elevated)", Self.background),
                .overlay("tintSurface/systemBackground (elevated)", Self.accent, 0.12, over: Self.background),
            ],
            level: .elevated
        )
        assertContrast(foreground: Self.onAccent, name: "OnAccent", on: [.solid("AccentColor", Self.accent)], level: .elevated)
    }

    /// 位置情報を使えないときの表示（#25）：カードの上の注意色の記号と、副ボタンのアクセント色の文字。
    func testLocationPermissionStatusMeetsAA() {
        assertContrast(foreground: Self.caution, name: "CautionAccent", on: [.solid("cardSurface", Self.cardSurface)])
        assertContrast(
            foreground: Self.accent,
            name: "AccentColor",
            on: [.overlay("tintSurface/cardSurface", Self.accent, 0.12, over: Self.cardSurface)]
        )
    }

    func testContrastRatioMatchesKnownValues() {
        XCTAssertEqual(RGB(white: 1).contrast(with: RGB(white: 0)), 21, accuracy: 0.01)
        XCTAssertEqual(RGB(white: 1).contrast(with: RGB(white: 1)), 1, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func assertContrast(
        foreground: UIColor,
        name: String,
        on backdrops: [Backdrop],
        minimum: Double = textMinimum,
        level: UIUserInterfaceLevel = .base,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(userInterfaceLevel: level),
            ])
            let fg = RGB(foreground.resolvedColor(with: traits))
            for backdrop in backdrops {
                let ratio = fg.contrast(with: backdrop.resolved(in: traits))
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    minimum,
                    "\(name) on \(backdrop) (\(style == .light ? "light" : "dark")): \(String(format: "%.2f", ratio)):1",
                    file: file,
                    line: line
                )
            }
        }
    }
}

/// sRGB の色（0...1）。WCAG 2.x の相対輝度とコントラスト比を計算する。
private struct RGB {
    let r: Double
    let g: Double
    let b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(white: Double) {
        self.init(r: white, g: white, b: white)
    }

    /// 不透明として扱う。半透明の色は `blended(alpha:over:)` で下の面と合成してから使う。
    init(_ color: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let converted = color.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ).flatMap(UIColor.init(cgColor:)) ?? color
        converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(r: Double(red), g: Double(green), b: Double(blue))
    }

    func blended(alpha: CGFloat, over base: RGB) -> RGB {
        let a = Double(alpha)
        return RGB(r: r * a + base.r * (1 - a), g: g * a + base.g * (1 - a), b: b * a + base.b * (1 - a))
    }

    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    func contrast(with other: RGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
