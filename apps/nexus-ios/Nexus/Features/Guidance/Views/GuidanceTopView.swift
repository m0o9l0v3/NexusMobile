import SwiftUI

/// 案内タブの3分類目次（P09）。
struct GuidanceTopView: View {
    let store: GuidanceStore
    let routeStore: RouteRequestStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                Text("案内")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                if let outcome = routeStore.lastOutcome {
                    RouteRequestNoticeView(outcome: outcome) {
                        routeStore.dismissNotice()
                    }
                }

                content
            }
            .padding(.horizontal, NexusTheme.spacing20)
            .padding(.top, NexusTheme.spacing8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemBackground))
        .navigationTitle("案内")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.loadTopIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.topState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
                .accessibilityLabel("案内を読み込み中")

        case .loaded(let snapshot):
            snapshotContent(snapshot, savedMetadata: nil)

        case .saved(let snapshot, let metadata):
            snapshotContent(snapshot, savedMetadata: metadata)

        case .empty(let message):
            NexusStatusView(message: message)

        case .failed(let message):
            NexusStatusView(message: message) {
                Task { await store.retryTop() }
            }
        }
    }

    @ViewBuilder
    private func snapshotContent(
        _ snapshot: GuidanceTopSnapshot,
        savedMetadata: NexusSavedMetadata?
    ) -> some View {
        if let savedMetadata {
            SavedContentBannerView(metadata: savedMetadata)
        }

        ForEach(snapshot.sections) { section in
            GuidanceMenuSectionView(section: section)
        }
    }
}
