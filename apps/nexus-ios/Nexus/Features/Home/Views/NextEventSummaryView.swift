import SwiftUI

struct NextEventSummaryView: View {
    @ScaledMetric(relativeTo: .title3) private var timeColumnWidth: CGFloat = 70

    let event: HomeEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(NexusTheme.eventAccent)
                    .frame(width: 4, height: 44)
                    .accessibilityHidden(true)

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
                .frame(minWidth: timeColumnWidth, alignment: .leading)

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(NexusTheme.surface, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 98)
            .contentShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .nexusCard()
        .accessibilityLabel(
            "次の体験イベント、\(event.timeText)、\(event.title)、\(event.locationName)"
        )
        .accessibilityHint("イベント詳細への遷移要求を送ります")
        .accessibilitySortPriority(80)
    }
}
