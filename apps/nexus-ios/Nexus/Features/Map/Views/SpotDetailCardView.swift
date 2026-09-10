import SwiftUI

/// Figma `2640:1591` Spot Detail / mb_f2_cr_2a。
///
/// **地点詳細の View はこれ1つだけ。** 探すタブは `SpotDetailPresentation` を生成できないので、
/// 独自の地点詳細を持てない。Home・案内・Map の検索も同じこのカードへ集まる。
///
/// Figma は場所行に Lucide の `map-pinned` を使っているが、ライセンスと採用記録が
/// 未確認のため SF Symbols `mappin.and.ellipse` で代替する（見た目の差は報告する）。
struct SpotDetailCardView: View {
    let presentation: SpotDetailPresentation
    let savedMetadata: NexusSavedMetadata?
    let onRequestRoute: () -> Void
    let onDismiss: () -> Void

    private var summary: SpotSummary { presentation.summary }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            if let savedMetadata {
                SavedContentBannerView(metadata: savedMetadata)
            }

            HStack(alignment: .top, spacing: NexusTheme.spacing8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.kind.displayName)
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)

                    Text(summary.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilitySortPriority(100)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                .contentShape(Rectangle())
                .accessibilityLabel("地点詳細を閉じる")
            }

            HStack(spacing: NexusTheme.spacing8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(locationText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("場所、\(locationText)")

            if let descriptionText = presentation.descriptionText {
                Text(descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let scheduleText = presentation.scheduleText {
                Label(scheduleText, systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let relatedEvent = presentation.relatedEvent {
                VStack(alignment: .leading, spacing: 2) {
                    Text(relatedEvent.title)
                        .font(.subheadline.weight(.semibold))

                    if let scheduleText = relatedEvent.scheduleText {
                        Text(scheduleText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NexusTheme.spacing12)
                .nexusPanel(NexusTheme.tintSurface, cornerRadius: NexusTheme.controlCornerRadius)
                .accessibilityElement(children: .combine)
            }

            Button(action: onRequestRoute) {
                Label("経路を確認", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("\(summary.displayName)への経路確認を要求します")
        }
        .padding(NexusTheme.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusFloatingSurface(cornerRadius: 24)
    }

    private var locationText: String {
        let text = summary.locationText
        return text.isEmpty ? "場所は未提供" : text
    }
}
