import SwiftUI

/// Figma `2640:1591` Spot Detail / mb_f2_cr_2a（Figma のフレーム名。ID は E1-7 の `mb_2f_cl_001`）。
///
/// **地点詳細の View はこれ1つだけ。** 探すタブは `SpotDetailPresentation` を生成できないので、
/// 独自の地点詳細を持てない。Home・案内・Map の検索も同じこのカードへ集まる。
///
/// Figma は場所行に Lucide の `map-pinned` を使っているが、ライセンスと採用記録が
/// 未確認のため SF Symbols `mappin.and.ellipse` で代替する（見た目の差は報告する）。
struct SpotDetailCardView: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let presentation: SpotDetailPresentation
    let savedMetadata: NexusSavedMetadata?
    let onRequestRoute: () -> Void
    /// イベント欄の会場への経路要求。中止でない枠の会場にだけ出す（EV-O1）。
    var onRequestVenueRoute: (CanonicalSpotID) -> Void = { _ in }
    let onDismiss: () -> Void

    private var summary: SpotSummary { presentation.summary }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            if typeSize.isAccessibilitySize, let savedMetadata {
                // 保存版の版・日時も全文を読めるよう、詳細と一緒にスクロールする。
                ScrollView {
                    VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                        header
                        SavedContentBannerView(metadata: savedMetadata)
                        details
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                if let savedMetadata {
                    SavedContentBannerView(metadata: savedMetadata)
                }

                header

                // イベント欄で内容が長くなったときだけスクロールさせる。経路の操作は常に見える位置に残す。
                ViewThatFits(in: .vertical) {
                    details
                    ScrollView {
                        details
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }

            Button(action: onRequestRoute) {
                Label("経路を確認", systemImage: "play.fill")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    // ダークのアクセント色は明るいため、システム既定の白ではなく OnAccent（ダークは黒）にする（#78）。
                    .foregroundStyle(NexusTheme.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("\(summary.displayName)への経路確認を要求します")
        }
        .padding(NexusTheme.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusFloatingSurface(cornerRadius: 24)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: NexusTheme.spacing8) {
            VStack(alignment: .leading, spacing: 2) {
                if let kind = summary.kind {
                    Text(kind.displayName)
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }

                Text(summary.displayName)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(100)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.nexusPressableCircle)
            .accessibilityLabel("地点詳細を閉じる")
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            HStack(spacing: NexusTheme.spacing8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body)
                    .frame(minWidth: 24, minHeight: 24)
                    .accessibilityHidden(true)

                Text(locationText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("場所、\(locationText)")

            if let event = presentation.event {
                SpotEventSectionView(section: event, onRequestRoute: onRequestVenueRoute)
            }

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationText: String {
        let text = summary.locationText
        return text.isEmpty ? "場所は未提供" : text
    }
}
