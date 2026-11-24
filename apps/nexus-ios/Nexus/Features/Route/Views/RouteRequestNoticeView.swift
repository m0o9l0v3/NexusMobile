import SwiftUI

/// 経路確認要求の結果を、要求元のタブ内でそのまま伝える通知。
///
/// 経路を確認しても、利用者が開いているタブを保持する。
struct RouteRequestNoticeView: View {
    let outcome: RouteRequestOutcome
    let onDismiss: () -> Void
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        let message = outcome.statusMessage
        HStack(alignment: .top, spacing: NexusTheme.spacing12) {
            Image(systemName: message.systemImageName)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.subheadline.weight(.semibold))

                if let detail = message.detail {
                    Text(detail)
                        .monospacedDigit()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let actionTitle, let onAction {
                    Button(action: onAction) {
                        Text(actionTitle)
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, NexusTheme.spacing12)
                            .padding(.vertical, NexusTheme.spacing8)
                            .frame(minHeight: NexusTheme.minimumTapTarget)
                            .foregroundStyle(Color.accentColor)
                            .background(NexusTheme.tintSurface, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.nexusPressableCapsule)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.nexusPressableCircle)
            .accessibilityLabel("通知を閉じる")
        }
        .padding(NexusTheme.spacing12)
        .nexusFloatingSurface(cornerRadius: NexusTheme.cardCornerRadius)
        .accessibilityElement(children: .contain)
    }

    private var iconColor: Color {
        if case .routeFailure = outcome { return NexusTheme.cautionAccent }
        return .secondary
    }
}
