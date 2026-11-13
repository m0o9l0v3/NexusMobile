import SwiftUI

/// Figma `2720:5366` Guidance/Common/UpdateStatus（State=Normal / Offline / Unavailable）。
///
/// 文言は Figma の3 Variant と一致させる。状態は色だけでなく、記号と文言でも区別する。
///
/// 記事に確認記録（`GuidanceConfirmation`）があるときは、同じ位置に**原稿の確認日**を出す（E6-6 §3）。
/// Figma 側の改訂（U-3）はまだなので、既存の部品の形のまま文言だけを差し替える最小の表示にしている。
struct GuidanceUpdateStatusView: View {
    let status: GuidanceUpdateStatus
    let confirmation: GuidanceConfirmation?

    init(status: GuidanceUpdateStatus, confirmation: GuidanceConfirmation? = nil) {
        self.status = status
        self.confirmation = confirmation
    }

    init(article: GuidanceArticle) {
        self.init(status: article.updateStatus, confirmation: article.confirmation)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: NexusTheme.spacing8) {
            Image(systemName: confirmation == nil ? status.systemImageName : "checkmark.seal")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(confirmation?.statusText ?? status.message)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                if let confirmation {
                    Text(confirmation.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NexusTheme.spacing12)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(NexusTheme.surface, cornerRadius: NexusTheme.spacing8)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: NexusTheme.spacing12) {
        ForEach(GuidanceUpdateStatus.allCases, id: \.self) { status in
            GuidanceUpdateStatusView(status: status)
        }
    }
    .padding(NexusTheme.contentPadding)
}
#endif
