import SwiftUI

struct HomeView: View {
    @StateObject private var store: HomeStore

    private let onRouteRequest: (AppRouteRequest) -> Void

    init(
        client: HomeClient,
        initialState: HomeViewState = .idle,
        onRouteRequest: @escaping (AppRouteRequest) -> Void
    ) {
        _store = StateObject(wrappedValue: HomeStore(client: client, initialState: initialState))
        self.onRouteRequest = onRouteRequest
    }

    var body: some View {
        ScrollView {
            VStack(spacing: NexusTheme.sectionSpacing) {
                HomeHeaderView()

                HomeSearchEntryView {
                    onRouteRequest(.search(.empty))
                }

                stateContent
            }
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .task {
            await store.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch store.state {
        case .idle, .loading:
            HomeLoadedContentView(
                snapshot: .loadingPlaceholder,
                onRouteRequest: { _ in }
            )
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ホームを読み込み中")

        case .loaded(let snapshot):
            HomeLoadedContentView(snapshot: snapshot, onRouteRequest: onRouteRequest)

        case .empty(let message):
            HomeStatusView(message: message)

        case .failed(let message):
            HomeStatusView(message: message) {
                Task { await store.retry() }
            }

        case .saved(let snapshot, let metadata):
            VStack(spacing: 12) {
                SavedHomeBannerView(metadata: metadata)
                HomeLoadedContentView(snapshot: snapshot, onRouteRequest: onRouteRequest)
            }
        }
    }
}

private struct HomeLoadedContentView: View {
    let snapshot: HomeSnapshot
    let onRouteRequest: (AppRouteRequest) -> Void

    var body: some View {
        VStack(spacing: NexusTheme.sectionSpacing) {
            if let nextEvent = snapshot.nextEvent {
                NextEventSummaryView(event: nextEvent) {
                    onRouteRequest(
                        .eventDetails(
                            eventID: nextEvent.id,
                            canonicalSpotID: nextEvent.canonicalSpotID
                        )
                    )
                }
            }

                HomeFeedView(
                    announcements: snapshot.announcements,
                    announcementBadgeCount: snapshot.announcementBadgeCount,
                    events: snapshot.featuredEvents,
                onRouteRequest: onRouteRequest
            )
        }
    }
}

private extension HomeSnapshot {
    static let loadingPlaceholder = HomeSnapshot(
        nextEvent: HomeEvent(
            id: "loading-next",
            canonicalSpotID: CanonicalSpotID(rawValue: "LOADING_SPOT"),
            category: "読み込み中",
            title: "イベントを読み込み中",
            timeText: "00:00",
            timeContextText: "確認中",
            locationName: "場所を確認中",
            systemImageName: "circle"
        ),
        announcements: [
            HomeAnnouncement(
                id: "loading-announcement-1",
                title: "お知らせを読み込み中です",
                elapsedText: "確認中",
                canonicalSpotID: nil
            ),
            HomeAnnouncement(
                id: "loading-announcement-2",
                title: "お知らせを読み込み中です",
                elapsedText: "確認中",
                canonicalSpotID: nil
            )
        ],
        featuredEvents: [
            HomeEvent(
                id: "loading-event-1",
                canonicalSpotID: CanonicalSpotID(rawValue: "LOADING_SPOT_1"),
                category: "読み込み中",
                title: "イベントを読み込み中",
                timeText: "00:00〜00:00",
                timeContextText: nil,
                locationName: "場所を確認中",
                systemImageName: "circle"
            ),
            HomeEvent(
                id: "loading-event-2",
                canonicalSpotID: CanonicalSpotID(rawValue: "LOADING_SPOT_2"),
                category: "読み込み中",
                title: "イベントを読み込み中",
                timeText: "00:00〜00:00",
                timeContextText: nil,
                locationName: "場所を確認中",
                systemImageName: "circle"
            )
        ]
    )
}
