import SwiftUI

struct HomeEventCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 210

    let event: HomeEvent
    let onDetails: () -> Void
    let onRoute: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: event.systemImageName)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(NexusTheme.tintSurface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                Text(event.category)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)

                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(event.timeText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 今日でない日付・終日・随時参加。別の日の同じ時刻の枠や、開催中に参加できる枠を区別する。
                if let timeContextText = event.timeContextText {
                    Text(timeContextText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label(event.locationName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 中止の枠も一覧に残し、中止と分かるようにする（E2-5 改訂1 EV-O1）。色だけに頼らず文字で示す。
                if event.isCancelled {
                    Label(event.cancelNote.map { "中止：\($0)" } ?? "中止", systemImage: "xmark.octagon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NexusTheme.cancelled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .labelStyle(.titleAndIcon)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 182, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(event.cardAccessibilityLabel)

            // 大きな文字サイズでは「詳細」「マップで見る」を横に並べると切れるため、縦に並べる（#78）。
            let buttonLayout = dynamicTypeSize.prefersVerticalControls
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(HStackLayout(spacing: 0))
            buttonLayout {
                Button(action: onDetails) {
                    Text("詳細")
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                    .accessibilityLabel(event.detailsButtonAccessibilityLabel)
                    .accessibilityHint("イベント詳細への遷移要求を送ります")

                // 中止の枠は会場へ向かう必要がないため、経路の操作を出さない。
                if !event.isCancelled {
                    if dynamicTypeSize.prefersVerticalControls {
                        Divider()
                            .accessibilityHidden(true)
                    } else {
                        Rectangle()
                            .fill(NexusTheme.border)
                            .frame(width: 1, height: 24)
                            .accessibilityHidden(true)
                    }

                    // Figma `HomeHIG/EventCard`：マップタブと同じピン＋「マップで見る」。押すとマップタブで経路を出す。
                    Button(action: onRoute) {
                        MapRouteButtonLabel()
                            .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                        .accessibilityLabel(event.mapButtonAccessibilityLabel)
                        .accessibilityHint("この地点への経路要求を送ります")
                }
            }
            .font(.caption)
            .buttonStyle(.nexusPressableRow)
            .foregroundStyle(Color.accentColor)
            .background(NexusTheme.surface)
        }
        .modifier(HomeEventCardWidth(width: cardWidth, fillsScrollWidth: dynamicTypeSize.isAccessibilitySize))
        .nexusCard()
    }
}

/// カードの幅。文字サイズに合わせて広げるが、大きな文字サイズでは画面からはみ出さないよう、
/// 横スクロールの表示幅いっぱいにとどめる（#78）。
private struct HomeEventCardWidth: ViewModifier {
    let width: CGFloat
    let fillsScrollWidth: Bool

    func body(content: Content) -> some View {
        if fillsScrollWidth {
            content.containerRelativeFrame(.horizontal, alignment: .top)
        } else {
            content.frame(width: width, alignment: .top)
        }
    }
}

/// 「マップで見る」のラベル（Figma `HomeHIG/EventCard`・`EventListHIG/SlotRow`）。
/// アイコンはマップタブと同じ `MapTabIcon`。押すとマップタブへ移って経路を出すことが分かるようにする。
struct MapRouteButtonLabel: View {
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            Image(AppTab.map.assetImageName ?? "MapTabIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            Text("マップで見る")
                .lineLimit(1)
        }
    }
}
