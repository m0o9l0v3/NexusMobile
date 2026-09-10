import SwiftUI

/// Figma `2720:5370` Guidance/Common/RelatedPlace。
///
/// **canonical ID が未確定のときはボタンを描画しない。**
/// Figma には常時有効な「場所を見る」「経路を確認」が描かれているが、
/// Implementation Notes（`2730:2942`）に「本館1階の canonical ID 未確定のため地点選択は行わない」、
/// #86 受入条件に「未提供なら推測文や無反応ボタンを出さない」とあるため、
/// ID が無い場合は説明表示だけに落とす。この差は Figma との差異として報告する。
struct GuidanceRelatedPlaceView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    let places: [GuidanceRelatedPlace]
    let unresolvedNote: String?

    var body: some View {
        if !places.isEmpty {
            VStack(spacing: NexusTheme.spacing12) {
                ForEach(places) { place in
                    placeCard(place)
                }
            }
        } else if let unresolvedNote {
            Label(unresolvedNote, systemImage: "mappin.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NexusTheme.spacing16)
                .nexusPanel(cornerRadius: NexusTheme.cardCornerRadius)
                .accessibilityElement(children: .combine)
        }
    }

    private func placeCard(_ place: GuidanceRelatedPlace) -> some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                Text(place.displayName)
                    .font(.headline)

                Text(place.supplementaryText ?? "地図を開いて場所や経路を確認できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                routeRequestHandler(.spotDetails(canonicalSpotID: place.canonicalSpotID))
            } label: {
                Text("場所を見る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("\(place.displayName)をマップで開きます")

            Button {
                routeRequestHandler(.route(destinationSpotID: place.canonicalSpotID))
            } label: {
                Text("経路を確認")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("\(place.displayName)への経路確認を要求します")
        }
        .padding(NexusTheme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(cornerRadius: NexusTheme.cardCornerRadius)
    }
}
