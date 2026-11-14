import SwiftUI

struct NextEventSummaryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var timeColumnWidth: CGFloat = 70

    let event: HomeEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // 大きな文字サイズでは時刻・内容・矢印を横に並べると1文字ずつ折り返して場所が消えるため、
            // 時刻と内容を縦に積み、飾りの帯と矢印は出さない（#78）。
            let isStacked = dynamicTypeSize.isAccessibilitySize
            let layout = isStacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                if !isStacked {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(NexusTheme.eventAccent)
                        .frame(width: 4, height: 44)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.timeText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    if let timeContextText = event.timeContextText {
                        Text(timeContextText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: isStacked ? nil : timeColumnWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.category)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)

                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Label(event.locationName, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isStacked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(NexusTheme.surface, in: Circle())
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 98)
            .contentShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius))
        }
        .buttonStyle(.nexusPressable)
        .nexusCard(elevation: .level3)
        .accessibilityLabel(event.nextEventAccessibilityLabel)
        .accessibilityHint("イベント詳細への遷移要求を送ります")
        .accessibilitySortPriority(80)
    }
}
