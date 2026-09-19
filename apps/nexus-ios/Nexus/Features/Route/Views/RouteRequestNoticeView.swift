import SwiftUI

/// 経路確認要求の結果を、要求元のタブ内でそのまま伝える通知。
///
/// 経路確認画面は Figma に存在せず経路探索も範囲外なので、タブを移動させない。
struct RouteRequestNoticeView: View {
    let outcome: RouteRequestOutcome
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: NexusTheme.spacing12) {
            Image(systemName: systemImageName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("通知を閉じる")
        }
        .padding(NexusTheme.spacing12)
        .nexusFloatingSurface(cornerRadius: NexusTheme.cardCornerRadius)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch outcome {
        case .accepted(let destination):
            return "「\(destination.canonicalSpotID.rawValue)」への経路を目的地に設定しました"
        case .unknownSpot(let canonicalSpotID):
            return "「\(canonicalSpotID.rawValue)」は経路データに登録されていません"
        case .unavailable(let message):
            return message.title
        }
    }

    private var detail: String? {
        switch outcome {
        case .accepted:
            return nil
        case .unknownSpot:
            // 別地点へ置換しない。何が起きたかだけを伝える。
            return "別の地点への案内は開始しません。地点の登録後に利用できます。"
        case .unavailable(let message):
            return message.detail
        }
    }

    private var systemImageName: String {
        switch outcome {
        case .accepted:
            return "checkmark.circle"
        case .unknownSpot:
            return "questionmark.circle"
        case .unavailable(let message):
            return message.systemImageName
        }
    }
}
