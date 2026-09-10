import SwiftUI

/// Figma `2599:2193` Section / QuickAccess「よく使う案内」の2×2グリッド。
/// 大きな文字サイズでは1列へ落とす。
struct GuidanceFrequentGridView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let items: [GuidanceMenuItem]

    private var columns: [GridItem] {
        let count = dynamicTypeSize.prefersVerticalControls ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: NexusTheme.spacing8),
            count: count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Text("よく使う案内")
                .font(.title3.weight(.semibold))

            LazyVGrid(columns: columns, spacing: NexusTheme.spacing8) {
                ForEach(items) { item in
                    Button {
                        routeRequestHandler(.guidanceArticle(articleID: item.id))
                    } label: {
                        Label(item.title, systemImage: item.systemImageName)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 60)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint(item.detail ?? "案内を開きます")
                }
            }
        }
    }
}
