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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let places: [GuidanceRelatedPlace]
    let unresolvedNote: String?

    var body: some View {
        if !places.isEmpty {
            VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                HStack(spacing: NexusTheme.spacing8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("関連する場所")
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                ForEach(places) { place in
                    placeCard(place)
                }
            }
        } else if let unresolvedNote {
            Label(unresolvedNote, systemImage: "mappin.slash")
                .font(.subheadline)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NexusTheme.spacing16)
                .nexusPanel(cornerRadius: NexusTheme.cardCornerRadius)
                .accessibilityElement(children: .combine)
        }
    }

    private func placeCard(_ place: GuidanceRelatedPlace) -> some View {
        let buttonLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: NexusTheme.spacing8))
            : AnyLayout(HStackLayout(spacing: NexusTheme.spacing12))

        return VStack(alignment: .leading, spacing: NexusTheme.spacing16) {
            HStack(alignment: .top, spacing: NexusTheme.spacing12) {
                Circle()
                    .fill(NexusTheme.tintSurface)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "map.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                    Text(place.displayName)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(place.supplementaryText ?? "地図を開いて場所や経路を確認できます。")
                        .font(.subheadline)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            buttonLayout {
                Button {
                    routeRequestHandler(.spotDetails(canonicalSpotID: place.canonicalSpotID))
                } label: {
                    Label("場所を見る", systemImage: "mappin.and.ellipse")
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("場所を見る")
                .accessibilityHint("\(place.displayName)をマップで開きます")

                Button {
                    routeRequestHandler(.route(destinationSpotID: place.canonicalSpotID))
                } label: {
                    Label("経路を確認", systemImage: "figure.walk")
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        // ダークのアクセント色は明るいため、システム既定の白ではなく OnAccent（ダークは黒）にする（#78）。
                        .foregroundStyle(NexusTheme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("経路を確認")
                .accessibilityHint("\(place.displayName)への経路確認を要求します")
            }
        }
        .padding(NexusTheme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusCard(cornerRadius: NexusTheme.cardCornerRadius, elevation: .level2)
    }
}
