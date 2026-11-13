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
