import SwiftUI

/// Figma `2720:5367` Guidance/Common/ArticleSection。見出し＋段落。
struct GuidanceArticleSectionView: View {
    let section: GuidanceSection

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
            if let heading = section.heading {
                Text(heading)
                    .font(.headline)
            }

            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
