import SwiftUI

/// 名称 + 種別・建物・階 の唯一の描画元。
///
/// 検索結果行（Figma `2637:1512`）と地点詳細ヘッダ（`2639:1550`）の両方がこれを使うため、
/// 表記と VoiceOver ラベルが2画面間で食い違わない。
struct SpotSummaryLabelView: View {
    let summary: SpotSummary
    let titleFont: Font

    init(summary: SpotSummary, titleFont: Font = .body.weight(.semibold)) {
        self.summary = summary
        self.titleFont = titleFont
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
            Text(summary.displayName)
                .font(titleFont)
                .foregroundStyle(.primary)

            // 種別も場所もない地点では、空の行を出さない。
            if !summary.supplementaryText.isEmpty {
                Text(summary.supplementaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityLabelText)
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: NexusTheme.spacing16) {
        SpotSummaryLabelView(
            summary: SpotSummary(
                canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
                displayName: "2A教室",
                kind: .classroom,
                buildingName: "教室棟",
                floorName: "2F"
            )
        )

        SpotSummaryLabelView(
            summary: SpotSummary(
                canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_SPOT_NO_LOCATION"),
                displayName: "場所未確定の地点",
                kind: .service
            )
        )

        SpotSummaryLabelView(
            summary: SpotSummary(
                canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_SPOT_NO_KIND"),
                displayName: "種別未設定の地点",
                kind: nil,
                buildingName: "教室棟"
            )
        )
    }
    .padding(NexusTheme.contentPadding)
}
#endif
