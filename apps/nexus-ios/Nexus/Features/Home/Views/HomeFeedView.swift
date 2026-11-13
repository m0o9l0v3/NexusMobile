import SwiftUI

/// この後のイベント（E2-5 改訂1 EV-D3）。お知らせは v1.0 では出さない（EV-D2）。
struct HomeFeedView: View {
    let events: [HomeEvent]
    let onRouteRequest: (AppRouteRequest) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EventSectionHeaderView {
                onRouteRequest(.allEvents)
            }

            if events.isEmpty {
                // 開催日はあるが、この後の枠が残っていない（最後の開催日の公開が終わった後など）。
                // Figma 未作成のため、今の Home の空の表示をそのまま使う（下書き §4 質問7）。
                HomeStatusView(message: HomeClient.noUpcomingEventsMessage)
            } else {
                eventCards
            }
        }
    }

    private var eventCards: some View {
        Group {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(events) { event in
                        HomeEventCardView(
                            event: event,
                            onDetails: {
                                onRouteRequest(
                                    .eventDetails(
                                        eventID: event.eventID,
                                        canonicalSpotID: event.canonicalSpotID
                                    )
                                )
                            },
                            onRoute: {
                                onRouteRequest(.route(destinationSpotID: event.canonicalSpotID))
                            }
                        )
                    }
                }
            }
            .accessibilitySortPriority(50)
        }
    }
}
