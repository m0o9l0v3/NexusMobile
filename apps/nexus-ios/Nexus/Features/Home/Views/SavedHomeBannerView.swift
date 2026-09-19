import SwiftUI

struct SavedHomeBannerView: View {
    let metadata: SavedHomeMetadata

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.title)
                    .font(.subheadline.weight(.semibold))

                if let detail = metadata.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(NexusTheme.tintSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
