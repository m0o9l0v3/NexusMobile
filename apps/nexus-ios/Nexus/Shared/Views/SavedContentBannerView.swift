import SwiftUI

/// 保存版（オフラインの保存済みデータ）を表示していることを示すバナー。
/// `SavedHomeBannerView` と同じ見た目を `NexusSavedMetadata` の上に持つ。
struct SavedContentBannerView: View {
    let metadata: NexusSavedMetadata

    var body: some View {
        HStack(spacing: NexusTheme.spacing12) {
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
        .padding(.horizontal, NexusTheme.spacing16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(NexusTheme.tintSurface)
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.controlCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    SavedContentBannerView(
        metadata: NexusSavedMetadata(
            title: "保存版を表示しています",
            detail: "最新情報は確認できていません。"
        )
    )
    .padding(NexusTheme.contentPadding)
}
#endif
