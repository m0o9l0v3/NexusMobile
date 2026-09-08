import SwiftUI

struct HomeStatusView: View {
    let message: HomeStateMessage
    let onRetry: (() -> Void)?

    init(message: HomeStateMessage, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: message.systemImageName)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let detail = message.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onRetry {
                Button("再試行", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(20)
        .nexusCard()
        .accessibilityElement(children: .contain)
    }
}
