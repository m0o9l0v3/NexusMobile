import SwiftUI

/// 0件・取得失敗・未提供などを表示する共通パネル。
/// `HomeStatusView` と同じ見た目・同じ構造を `NexusStateMessage` の上に持つ。
struct NexusStatusView: View {
    let message: NexusStateMessage
    let onRetry: (() -> Void)?
    let showsCard: Bool

    init(message: NexusStateMessage, showsCard: Bool = true, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
        self.showsCard = showsCard
    }

    @ViewBuilder
    var body: some View {
        if showsCard {
            content
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding(NexusTheme.spacing20)
                .nexusCard()
        } else {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, NexusTheme.spacing12)
        }
    }

    private var content: some View {
        VStack(spacing: NexusTheme.spacing12) {
            Image(systemName: message.systemImageName)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = message.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(showsCard ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onRetry {
                Button("再試行", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("取得失敗") {
    NexusStatusView(
        message: NexusStateMessage(
            title: "検索データを読み込めませんでした",
            detail: "データ取得先の接続後に再試行してください。",
            systemImageName: "wifi.slash"
        ),
        onRetry: {}
    )
    .padding(NexusTheme.contentPadding)
}

#Preview("0件") {
    NexusStatusView(
        message: NexusStateMessage(
            title: "該当する地点はありません",
            detail: "条件を解除すると、すべての地点を表示します。",
            systemImageName: "magnifyingglass"
        )
    )
    .padding(NexusTheme.contentPadding)
}
#endif
