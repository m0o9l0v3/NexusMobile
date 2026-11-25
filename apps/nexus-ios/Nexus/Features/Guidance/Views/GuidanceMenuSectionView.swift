import SwiftUI

/// P09 の分類見出しと記事の目次（Figma `2825:2315` / `2825:2547`）。
struct GuidanceMenuSectionView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var rowIconWidth = 26.0

    let section: GuidanceMenuSection

    // 小さい文字でも白／黒の下地とのコントラストを確保する。
    private let secondaryForeground = Color.primary.opacity(0.75)

    private var isEmergency: Bool { section.kind == .emergency }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(section.kind.heading, systemImage: section.kind.systemImageName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEmergency ? NexusTheme.cautionAccent : secondaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, NexusTheme.spacing16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .frame(minHeight: 40, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Divider()
                .overlay(isEmergency ? NexusTheme.cautionAccent.opacity(0.22) : .clear)
                .accessibilityHidden(true)

            ForEach(section.items) { item in
                if item.id != section.items.first?.id {
                    Divider()
                        .overlay(isEmergency ? NexusTheme.cautionAccent.opacity(0.22) : .clear)
                        .padding(.leading, NexusTheme.spacing16 + rowIconWidth + NexusTheme.spacing12)
                        .padding(.trailing, NexusTheme.spacing16)
                        .accessibilityHidden(true)
                }

                if let articleID = item.articleID {
                    Button {
                        routeRequestHandler(.guidanceArticle(articleID: articleID))
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.nexusPressableRow)
                } else {
                    row(item)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .background(isEmergency ? NexusTheme.cautionSurface : NexusTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius)
                .strokeBorder(isEmergency ? NexusTheme.cautionAccent : NexusTheme.border)
                .allowsHitTesting(false)
        }
        .nexusElevation(.level1)
    }

    private func row(_ item: GuidanceMenuItem) -> some View {
        HStack(spacing: NexusTheme.spacing12) {
            Image(systemName: item.topic.systemImageName)
                .font(.title3)
                .foregroundStyle(iconColor(for: item.topic))
                .frame(width: rowIconWidth)
                .accessibilityHidden(true)

            let layout = dynamicTypeSize.prefersVerticalControls
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing4))
                : AnyLayout(HStackLayout(spacing: NexusTheme.spacing8))

            layout {
                Text(item.topic.title)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if item.articleID == nil {
                    Text("準備中")
                        .font(.subheadline)
                        .foregroundStyle(secondaryForeground)
                }
            }

            if item.articleID != nil {
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(secondaryForeground)
                    .accessibilityHidden(true)
            }
        }
        .font(.body)
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing12)
        .nexusTappableRow(minHeight: 54)
    }

    private func iconColor(for topic: GuidanceMenuTopic) -> Color {
        switch topic {
        case .health: NexusTheme.cancelled
        case .help: NexusTheme.cautionAccent
        default: secondaryForeground
        }
    }
}
