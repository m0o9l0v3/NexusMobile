import SwiftUI

/// Figma `2720:5366` Guidance/Common/UpdateStatus（State=Normal / Offline / Unavailable）。
///
/// 文言は Figma の3 Variant と一致させる。状態は色だけでなく、記号と文言でも区別する。
struct GuidanceUpdateStatusView: View {
    let status: GuidanceUpdateStatus

    var body: some View {
        HStack(spacing: NexusTheme.spacing8) {
            Image(systemName: status.systemImageName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(status.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NexusTheme.spacing12)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(NexusTheme.surface, cornerRadius: NexusTheme.spacing8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.message)
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
