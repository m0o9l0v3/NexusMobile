import SwiftUI

/// P09 の分類見出しと記事の目次（Figma `2825:2315` / `2825:2547`）。
struct GuidanceMenuSectionView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let badgeDiameter: CGFloat = 34

    let section: GuidanceMenuSection
    @State private var selectionFeedbackCount = 0

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
                .padding(.top, 12)
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
                        .padding(.leading, NexusTheme.spacing16 + Self.badgeDiameter + NexusTheme.spacing12)
                        .padding(.trailing, NexusTheme.spacing16)
                        .accessibilityHidden(true)
                }

                if let articleID = item.articleID {
                    Button {
                        selectionFeedbackCount += 1
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
        .background {
            ZStack {
                NexusTheme.cardSurface
                if isEmergency {
                    NexusTheme.cautionSurface
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous)
                .strokeBorder(isEmergency ? NexusTheme.cautionAccent : NexusTheme.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .nexusElevation(.level1)
        .sensoryFeedback(.impact(weight: .light), trigger: selectionFeedbackCount)
    }

    private func row(_ item: GuidanceMenuItem) -> some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: NexusTheme.spacing12) {
            Circle()
                .fill(iconBadgeFill(for: item.topic))
                .frame(width: Self.badgeDiameter, height: Self.badgeDiameter)
                .overlay {
                    Image(systemName: item.topic.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(iconColor(for: item.topic))
                }
                .accessibilityHidden(true)

            let layout = dynamicTypeSize.prefersVerticalControls
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing4))
                : AnyLayout(HStackLayout(spacing: NexusTheme.spacing8))

            layout {
                Text(item.topic.title)
                    .font(.body.weight(item.articleID == nil ? .regular : .medium))
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
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, 10)
        .nexusTappableRow(minHeight: 50)
    }

    private func iconBadgeFill(for topic: GuidanceMenuTopic) -> Color {
        switch topic {
        case .health, .help: NexusTheme.cardSurface
        case .about: Color.primary.opacity(0.07)
        default: NexusTheme.tintSurface
        }
    }

    private func iconColor(for topic: GuidanceMenuTopic) -> Color {
        switch topic {
        case .health: NexusTheme.cancelled
        case .help: NexusTheme.cautionAccent
        case .about: secondaryForeground
        default: Color.accentColor
        }
    }
}
