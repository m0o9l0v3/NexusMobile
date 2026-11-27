import SwiftUI

/// Figma `2720:5367` Guidance/Common/ArticleSection。見出し＋段落。
struct GuidanceArticleSectionView: View {
    let section: GuidanceSection

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            if let heading = section.heading {
                Text(heading)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
