import SwiftUI

/// 地点詳細カードのイベント欄（#48、E2-5 改訂1）。Home の「詳細」から開いたときに出す。
///
/// Figma にフレームがないため、`docs/design-rules.md` に沿った最小の構成にしている
/// （Figma との差分は PR に記録して Figma 担当に渡す。EV-O3 と同じ進め方）。
struct SpotEventSectionView: View {
    let section: SpotEventSection
    let onRequestRoute: (CanonicalSpotID) -> Void

    var body: some View {
        switch section {
        case .published(let detail):
            published(detail)
        case .notPublished:
            // 取り下げなどで表示中の版にない。別のイベントで代用しない。
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("このイベントは掲載されていません")
                        .font(.subheadline.weight(.semibold))
                    Text("表示中の公開データに、このイベントはありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NexusTheme.spacing12)
            .nexusPanel(NexusTheme.tintSurface, cornerRadius: NexusTheme.controlCornerRadius)
            .accessibilityElement(children: .combine)
        }
    }

    private func published(_ detail: SpotEventDetail) -> some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.category)
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                Text(detail.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if let descriptionText = detail.descriptionText {
                Text(descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(detail.slots) { slot in
                SpotEventSlotRow(slot: slot, onRequestRoute: onRequestRoute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpotEventSlotRow: View {
    let slot: SpotEventSlot
    let onRequestRoute: (CanonicalSpotID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
            VStack(alignment: .leading, spacing: 2) {
                Label("\(slot.dateText) \(slot.timeText)", systemImage: "clock")
                    .font(.subheadline.monospacedDigit())

                if let modeText = slot.modeText {
                    Text(modeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 中止の枠も残し、中止と分かるようにする（EV-O1）。色だけに頼らず文字で示す。
                if slot.isCancelled {
                    Label(slot.cancelNote.map { "中止：\($0)" } ?? "中止", systemImage: "xmark.octagon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timeAccessibilityText)

            ForEach(Array(slot.venues.enumerated()), id: \.offset) { _, venue in
                HStack(spacing: NexusTheme.spacing8) {
                    Label(venueText(venue), systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 中止の枠は会場へ向かう必要がないため、経路の操作を出さない（EV-O1）。
                    if !slot.isCancelled {
                        Button("経路") { onRequestRoute(venue.canonicalSpotID) }
                            .font(.footnote)
                            .frame(minWidth: NexusTheme.minimumTapTarget, minHeight: NexusTheme.minimumTapTarget)
                            .contentShape(Rectangle())
                            .accessibilityLabel("\(venue.name)への経路を確認")
                    }
                }
            }
        }
        .padding(NexusTheme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(NexusTheme.tintSurface, cornerRadius: NexusTheme.controlCornerRadius)
        .accessibilityElement(children: .contain)
    }

    private func venueText(_ venue: SpotEventVenue) -> String {
        venue.note.map { "\(venue.name)（\($0)）" } ?? venue.name
    }

    private var timeAccessibilityText: String {
        let base = [slot.dateText, slot.timeText, slot.modeText].compactMap { $0 }.joined(separator: "、")
        guard slot.isCancelled else { return base }
        return "中止、" + base + (slot.cancelNote.map { "、\($0)" } ?? "")
    }
}
