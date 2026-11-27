import SwiftUI

/// 保存版（オフラインの保存済みデータ）を表示していることを示すバナー。
/// `SavedHomeBannerView` と同じ見た目を `NexusSavedMetadata` の上に持つ。
struct SavedContentBannerView: View {
    let metadata: NexusSavedMetadata

    var body: some View {
        HStack(spacing: NexusTheme.spacing12) {
            Image(systemName: "archivebox")
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 24, minHeight: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.title)
                    .font(.subheadline.weight(.semibold))

                if let detail = metadata.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .fixedSize(horizontal: false, vertical: true)
        .background(NexusTheme.tintSurface)
        .background(NexusTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.controlCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    SavedContentBannerView(
        metadata: NexusSavedMetadata(
            title: "保存版（最新未確認）",
            detail: "最新情報は確認できていません。"
        )
    )
    .padding(NexusTheme.contentPadding)
}
#endif
