import SwiftUI

/// Figma `2599:2195`「来場案内」/ `2599:2196`「学校を知る」のグループ化リスト。
struct GuidanceMenuSectionView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    let section: GuidanceMenuSection

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Text(section.heading)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
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
                        .nexusTappableRow(minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityHint(item.detail ?? "案内を開きます")

                    if index < section.items.count - 1 {
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
}
