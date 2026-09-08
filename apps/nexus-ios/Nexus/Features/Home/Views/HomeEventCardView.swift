import SwiftUI

struct HomeEventCardView: View {
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

                Label(event.locationName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .labelStyle(.titleAndIcon)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 182, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(event.category)、\(event.title)、\(event.timeText)、\(event.locationName)"
            )

            HStack(spacing: 0) {
                Button("詳細", action: onDetails)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityHint("イベント詳細への遷移要求を送ります")

                Rectangle()
                    .fill(NexusTheme.border)
                    .frame(width: 1, height: 24)
                    .accessibilityHidden(true)

                Button("経路を確認", action: onRoute)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityHint("この地点への経路要求を送ります")
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .background(NexusTheme.surface)
        }
        .frame(width: cardWidth, alignment: .top)
        .nexusCard()
    }
}
