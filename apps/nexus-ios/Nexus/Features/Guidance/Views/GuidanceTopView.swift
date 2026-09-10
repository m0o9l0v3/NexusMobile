import SwiftUI

/// 案内タブのトップ。Figma `2595:760` / `2599:2190` ScrollView / Guidance。
struct GuidanceTopView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    let store: GuidanceStore
    let routeStore: RouteRequestStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing20) {
                if let outcome = routeStore.lastOutcome {
                    RouteRequestNoticeView(outcome: outcome) {
                        routeStore.dismissNotice()
                    }
                }

                content
            }
            .padding(.horizontal, NexusTheme.spacing16)
            .padding(.top, NexusTheme.spacing8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemBackground))
        .navigationTitle("案内")
        .navigationBarTitleDisplayMode(.large)
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

        if let todayCard = snapshot.todayCard {
            GuidanceTodayCardView(card: todayCard)
                .accessibilitySortPriority(100)
        }

        if !snapshot.frequentItems.isEmpty {
            GuidanceFrequentGridView(items: snapshot.frequentItems)
                .accessibilitySortPriority(90)
        }

        if !snapshot.troubleItems.isEmpty {
            GuidanceTroubleListView(items: snapshot.troubleItems)
                .accessibilitySortPriority(80)
        }

        ForEach(snapshot.sections) { section in
            GuidanceMenuSectionView(section: section)
        }

        GuidanceUpdateStatusView(status: snapshot.updateStatus)
    }
}
