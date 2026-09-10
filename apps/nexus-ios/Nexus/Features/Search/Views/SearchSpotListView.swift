import SwiftUI

/// Figma `2646:1644` Section / All Spots ・ `2637:1529`。
/// 見出し＋件数と、角丸16ptのリストをまとめる。
struct SearchSpotListView: View {
    let headingText: String
    let totalCount: Int
    let spots: [SpotSummary]
    let onSelect: (SpotSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            HStack {
                Text(headingText)
                    .font(.headline)

                Spacer(minLength: NexusTheme.spacing8)

                Text("\(totalCount)件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(headingText)、\(totalCount)件")

            LazyVStack(spacing: 0) {
                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    SearchResultRowView(
                        summary: spot,
                        showsSeparator: index < spots.count - 1,
                        action: { onSelect(spot) }
                    )
                }
            }
            .padding(.horizontal, NexusTheme.spacing16)
            .background(
                Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                    .stroke(NexusTheme.border, lineWidth: 1)
            }
        }
    }
}
