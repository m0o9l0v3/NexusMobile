import SwiftUI

/// 設計・正式データがまだ存在しない遷移先を、未提供として明示する画面。
struct NotProvidedView: View {
    let topic: NotProvidedTopic

    var body: some View {
        ScrollView {
            NexusStatusView(
                message: NexusStateMessage(
                    title: topic.title,
                    detail: topic.detail,
                    systemImageName: "tray"
                )
            )
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.top, NexusTheme.contentPadding)
        }
        .background(Color(.systemBackground))
        .navigationTitle(topic.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NotProvidedView(topic: .announcementList)
    }
}
#endif
