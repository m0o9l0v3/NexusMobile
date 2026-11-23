import SwiftUI

struct CampusMapSpotMark: View {
    let appearance: CampusMapContent.Pin.Appearance
    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isFocused {
            focusedPin
        } else {
            badge.nexusElevation(.level1)
        }
    }

    private var symbol: String {
        switch appearance {
        case .building: return "building.2.fill"
        case .classroom: return "book.fill"
        case .entrance: return "door.left.hand.open"
        case .service: return "bell.fill"
        case .facility: return "building.columns.fill"
        case .landmark: return "mappin"
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch appearance {
        case .building:
            filledBadge(RoundedRectangle(cornerRadius: 7), color: NexusTheme.mapBuildingPin, size: 22)
        case .service:
            filledBadge(Circle(), color: .accentColor, size: 24)
        case .facility:
            filledBadge(Circle(), color: NexusTheme.mapFacilityPin, size: 22)
        case .landmark:
            filledBadge(Circle(), color: .accentColor, size: 20)
        case .classroom:
            Circle()
                .fill(NexusTheme.mapPinHalo)
                .overlay {
                    Circle().inset(by: 1.5).strokeBorder(NexusTheme.mapClassroomPin, lineWidth: 1.5)
                    Circle().fill(NexusTheme.mapClassroomPin).frame(width: 4, height: 4)
                }
                .frame(width: 14, height: 14)
        case .entrance:
            Circle()
                .fill(NexusTheme.mapPinHalo)
                .overlay {
                    Circle().inset(by: 1).strokeBorder(NexusTheme.mapEntrancePin, lineWidth: 1)
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NexusTheme.mapEntrancePin)
                }
                .frame(width: 18, height: 18)
        }
    }

    private func filledBadge<S: InsettableShape>(_ shape: S, color: Color, size: CGFloat) -> some View {
        shape
            .fill(color)
            .overlay { shape.strokeBorder(NexusTheme.mapPinHalo, lineWidth: 1.5) }
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NexusTheme.onAccent)
            }
            .frame(width: size, height: size)
    }

    private var focusedPin: some View {
        MapTeardropPin(
            fill: NexusTheme.eventAccent,
            halo: NexusTheme.mapFocusedPinContrast,
            width: 30,
            height: 38
        ) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NexusTheme.onAccent)
                .frame(width: 19, height: 19)
                .background(colorScheme == .light ? NexusTheme.mapFocusedPinContrast : NexusTheme.eventAccent, in: Circle())
        }
        .nexusElevation(.level2)
        .background(alignment: .bottom) {
            // 先端の座標を中心にリングを敷く。静止したままで選択を示す。
            Ellipse()
                .strokeBorder(NexusTheme.mapFocusedPinContrast, lineWidth: 4)
                .overlay { Ellipse().inset(by: 1).strokeBorder(NexusTheme.eventAccent, lineWidth: 2) }
                .frame(width: 24, height: 12)
                .offset(y: 6)
        }
    }
}

struct CampusMapRouteMark: View {
    let isOrigin: Bool
    let emphasizesLabel: Bool

    // ダークの地図では道路も暗い。白縁で地図とマーカーの境界を出す。
    private let rim = NexusTheme.mapRoutePinCenter

    var body: some View {
        mark
            .nexusElevation(.level2)
            // ラベルを大きくしても、ノードの中心・目的地ピンの先端を地図の座標に合わせる。
            .overlay(alignment: .top) {
                Text(isOrigin ? "出発" : "目的地")
                    .font((emphasizesLabel ? Font.caption : .caption2).weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize()
                    .padding(.horizontal, NexusTheme.spacing4)
                    .background(NexusTheme.cardSurface, in: Capsule())
                    .overlay { Capsule().strokeBorder(NexusTheme.border, lineWidth: 1) }
                    .alignmentGuide(.top) { $0[.bottom] + NexusTheme.spacing4 }
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var mark: some View {
        if isOrigin {
            Circle()
                .fill(NexusTheme.mapRouteOriginPin)
                .overlay { Circle().strokeBorder(rim, lineWidth: 1.5) }
                .overlay { centerDot(size: 9) }
                .frame(width: 26, height: 26)
        } else {
            MapTeardropPin(fill: NexusTheme.mapDestinationPin, halo: rim, width: 32, height: 40) {
                centerDot(size: 11)
            }
        }
    }

    private func centerDot(size: CGFloat) -> some View {
        Circle().fill(NexusTheme.mapRoutePinCenter).frame(width: size, height: size)
    }
}

private struct MapTeardropPin<Glyph: View>: View {
    let fill: Color
    let halo: Color
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let glyph: Glyph

    var body: some View {
        Teardrop()
            .fill(fill)
            .overlay {
                Teardrop().stroke(halo, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            .overlay(alignment: .top) {
                glyph.frame(height: width)
            }
            .frame(width: width, height: height)
    }

    private struct Teardrop: Shape {
        func path(in rect: CGRect) -> Path {
            // 線幅の半分を内側に収め、外縁を含む先端をフレームの下端に合わせる。
            let outline = rect.insetBy(dx: 1, dy: 1)
            let radius = outline.width / 2
            let center = CGPoint(x: outline.midX, y: outline.minY + radius)
            let tip = CGPoint(x: outline.midX, y: outline.maxY)
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .zero, clockwise: false)
            path.addQuadCurve(to: tip, control: CGPoint(x: outline.maxX, y: center.y + radius * 0.65))
            path.addQuadCurve(
                to: CGPoint(x: outline.minX, y: center.y),
                control: CGPoint(x: outline.minX, y: center.y + radius * 0.65)
            )
            path.closeSubpath()
            return path
        }
    }
}
