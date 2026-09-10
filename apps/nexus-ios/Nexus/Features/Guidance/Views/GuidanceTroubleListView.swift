import SwiftUI

/// Figma `2599:2194` Section / Help「困ったとき」。一覧上部に置く（#86 G02）。
struct GuidanceTroubleListView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    let items: [GuidanceMenuItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(NexusTheme.cautionAccent)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                Text("困ったとき")
                    .font(.headline)
                    .foregroundStyle(NexusTheme.cautionAccent)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(NexusTheme.cautionSurface)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    routeRequestHandler(.guidanceArticle(articleID: item.id))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.systemImageName)
                            .font(.body)
                            .frame(width: 20, height: 20)
                            .accessibilityHidden(true)

                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .nexusTappableRow(minHeight: 60)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityHint(item.detail ?? "対処の案内を開きます")

                if index < items.count - 1 {
                    Divider().padding(.leading, 44).accessibilityHidden(true)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                .stroke(NexusTheme.border, lineWidth: 1)
        }
    }
}
