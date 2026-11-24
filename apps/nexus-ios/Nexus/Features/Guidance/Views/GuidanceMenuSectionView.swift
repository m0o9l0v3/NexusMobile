import SwiftUI

/// P09 の分類見出しと記事の目次（Figma `2825:2315` / `2825:2547`）。
struct GuidanceMenuSectionView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var rowIconWidth = 20.0

    let section: GuidanceMenuSection

    // 小さい文字でも白／黒の下地とのコントラストを確保する。
    private let secondaryForeground = Color.primary.opacity(0.75)

    private var isEmergency: Bool { section.kind == .emergency }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(section.kind.heading, systemImage: section.kind.systemImageName)
                .font(.footnote)
                .foregroundStyle(isEmergency ? NexusTheme.cautionAccent : secondaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, NexusTheme.spacing8)
                .frame(minHeight: 35, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.items) { item in
                if item.id != section.items.first?.id {
                    Divider()
                        .overlay(isEmergency ? NexusTheme.cautionAccent.opacity(0.22) : .clear)
                        .padding(.leading, 14 + rowIconWidth + NexusTheme.spacing12)
                        .padding(.trailing, 14)
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
    }

    private func row(_ item: GuidanceMenuItem) -> some View {
        HStack(spacing: NexusTheme.spacing12) {
            Image(systemName: item.topic.systemImageName)
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
                        .font(.footnote)
                        .foregroundStyle(secondaryForeground)
                }
            }

            if item.articleID != nil {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(secondaryForeground)
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, NexusTheme.spacing8)
        .nexusTappableRow(minHeight: 45)
    }

    private func iconColor(for topic: GuidanceMenuTopic) -> Color {
        switch topic {
        case .health: NexusTheme.cancelled
        case .help: NexusTheme.cautionAccent
        default: secondaryForeground
        }
    }
}
