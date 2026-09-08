import SwiftUI

struct HomeFeedView: View {
    let announcements: [HomeAnnouncement]
    let announcementBadgeCount: Int?
    let events: [HomeEvent]
    let onRouteRequest: (AppRouteRequest) -> Void

    var body: some View {
        VStack(spacing: 0) {
            AnnouncementSectionView(
                announcements: announcements,
                badgeCount: announcementBadgeCount,
                onShowAll: { onRouteRequest(.allAnnouncements) },
                onSelect: { announcement in
                    onRouteRequest(
                        .announcementDetails(
                            id: announcement.id,
                            canonicalSpotID: announcement.canonicalSpotID
                        )
                    )
                }
            )

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
                                        eventID: event.id,
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
