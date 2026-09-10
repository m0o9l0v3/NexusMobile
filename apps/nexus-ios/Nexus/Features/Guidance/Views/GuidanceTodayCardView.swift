import SwiftUI

/// Figma `2599:2192` Section / Today「本日のご案内」。
///
/// 固定の受付時間と場所のみを出す。「受付中」など進行状況の推定は表示しない。
struct GuidanceTodayCardView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let card: GuidanceTodayCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            if let scheduleText = card.scheduleText {
                detailRow(systemImageName: "clock", text: scheduleText, accessibilityPrefix: "受付時間")
            }

            if let locationText = card.locationText {
                detailRow(systemImageName: "location", text: locationText, accessibilityPrefix: "場所")
            }

            actions
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(NexusTheme.tintSurface, cornerRadius: NexusTheme.cardCornerRadius)
    }

    private func detailRow(
        systemImageName: String,
        text: String,
        accessibilityPrefix: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImageName)
                .font(.body)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityPrefix)、\(text)")
    }

    @ViewBuilder
    private var actions: some View {
        let buttons = ViewThatFitsActions(
            card: card,
            routeRequestHandler: routeRequestHandler
        )

        if dynamicTypeSize.prefersVerticalControls {
            VStack(spacing: NexusTheme.spacing8) { buttons }
        } else {
            HStack(spacing: NexusTheme.spacing8) { buttons }
        }
    }
}

/// 「当日の流れ」「マップで見る」。遷移先が未確定のボタンは描画しない。
private struct ViewThatFitsActions: View {
    let card: GuidanceTodayCard
    let routeRequestHandler: (AppRouteRequest) -> Void

    var body: some View {
        if let primaryArticleID = card.primaryArticleID {
            Button {
                routeRequestHandler(.guidanceArticle(articleID: primaryArticleID))
            } label: {
                Label(card.primaryActionTitle, systemImage: "info.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }

        if let mapSpotID = card.mapSpotID {
            Button {
                routeRequestHandler(.spotDetails(canonicalSpotID: mapSpotID))
            } label: {
                Label {
                    Text("マップで見る")
                } icon: {
                    // 既存の採用済み SVG（lucide/map-pin）をテンプレートレンダリングで再利用する。
                    Image("MapTabIcon").renderingMode(.template)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("受付の場所をマップで開きます")
        }
    }
}
