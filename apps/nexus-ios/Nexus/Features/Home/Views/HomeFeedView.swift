import SwiftUI

/// この後のイベント（E2-5 改訂1 EV-D3）。お知らせは v1.0 では出さない（EV-D2）。
struct HomeFeedView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let events: [HomeEvent]
    /// bundle に公開済みのイベントがあるか。ないときは「終了」ではなく「まだ公開されていない」と伝える。
    var hasPublishedEvents: Bool = true
    let onRouteRequest: (AppRouteRequest) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EventSectionHeaderView {
                onRouteRequest(.allEvents)
            }

            if events.isEmpty {
                // 開催日はあるが、この後の枠が残っていない（最後の開催日の公開が終わった後など）。
                // Figma 未作成のため、今の Home の空の表示をそのまま使う（下書き §4 質問7）。
                HomeStatusView(
                    message: hasPublishedEvents
                        ? HomeClient.noUpcomingEventsMessage
                        : HomeClient.noPublishedEventsMessage
                )
            } else if dynamicTypeSize.isAccessibilitySize {
                eventCards.scrollTargetBehavior(.viewAligned)
            } else {
                eventCards
            }
        }
    }

    private var eventCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // 件数は `HomeEventProjection.upcomingLimit` までなので Lazy にしない。
            // LazyHStack は最初に見えたカードの高さで並びの高さを決めるため、大きな文字サイズで
            // 後ろの背の高いカード（中止の理由がある枠など）の下が切れていた（#78）。
            HStack(alignment: .top, spacing: 12) {
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
            .scrollTargetLayout(isEnabled: dynamicTypeSize.isAccessibilitySize)
        }
        .accessibilitySortPriority(50)
    }
}
