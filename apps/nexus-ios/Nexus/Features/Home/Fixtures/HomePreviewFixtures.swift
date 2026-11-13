#if DEBUG
import Foundation
import SwiftUI

enum HomePreviewFixtures {
    static let loaded = HomeSnapshot(
        dayOverview: dayOverviews[0],
        nextEvent: events[0],
        upcomingEvents: events
    )

    /// 開催日カードの各状態（Figma `2790:1744`）。日付・理由は検討用のサンプル。
    static let dayOverviews = [
        HomeDayOverview(
            dayID: "PREVIEW_DAY_OPEN", occurrenceName: "検討用の開催回", dateText: "8月1日（日）10:00〜15:00",
            status: .open, detailText: "15:00まで公開中です", cancelNote: nil, otherDays: []
        ),
        HomeDayOverview(
            dayID: "PREVIEW_DAY_UPCOMING", occurrenceName: "検討用の開催回", dateText: "8月1日（日）10:00〜15:00",
            status: .upcoming, detailText: "開催まであと3日", cancelNote: nil,
            otherDays: [HomeOtherDay(id: "PREVIEW_DAY_2", dateText: "8月2日（月）10:00〜15:00", isCancelled: false)]
        ),
        HomeDayOverview(
            dayID: "PREVIEW_DAY_ENDED", occurrenceName: "検討用の開催回", dateText: "8月1日（日）10:00〜15:00",
            status: .ended, detailText: "この日の公開は終了しました", cancelNote: nil, otherDays: []
        ),
        HomeDayOverview(
            dayID: "PREVIEW_DAY_CANCELLED", occurrenceName: "検討用の開催回", dateText: "8月1日（日）10:00〜15:00",
            status: .cancelled, detailText: "この日の開催は中止になりました", cancelNote: "検討用の理由", otherDays: []
        ),
    ]

    /// 案内ショートカット。記事は案内タブの検討用データ（`GuidancePreviewFixtures`）。
    static let guidanceShortcuts = [
        HomeGuidanceShortcut(shortcut: .reception, articleID: GuidancePreviewFixtures.receptionID),
        HomeGuidanceShortcut(shortcut: .help, articleID: GuidancePreviewFixtures.lostID),
        HomeGuidanceShortcut(shortcut: .access, articleID: GuidancePreviewFixtures.accessID),
    ]

    static let emptyMessage = HomeStateMessage(
        title: "この後のイベントはありません",
        detail: "この表示文言と次の操作は、正式なデータ運用の承認後に確定します。",
        systemImageName: "tray"
    )

    static let failureMessage = HomeStateMessage(
        title: "ホームを読み込めませんでした",
        detail: "通信状態を確認して、もう一度お試しください。",
        systemImageName: "wifi.slash"
    )

    static let savedMetadata = SavedHomeMetadata(
        title: "保存版を表示中",
        detail: "最新情報を確認できない検討用表示です"
    )

    static let events = [
        HomeEvent(
            id: "PREVIEW_EVENT_DRONE",
            canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_MB_2A"),
            category: "テクノロジー",
            title: "ドローン体験",
            timeText: "10:00〜11:30",
            timeContextText: "検討用",
            locationName: "2A教室",
            systemImageName: "airplane"
        ),
        HomeEvent(
            id: "PREVIEW_EVENT_CA",
            canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_DESIGN_LAB"),
            category: "デザイン",
            title: "CAモックアップ体験",
            timeText: "13:00〜14:00",
            timeContextText: nil,
            locationName: "設計実習室",
            systemImageName: "person.fill"
        ),
        HomeEvent(
            id: "PREVIEW_EVENT_METALWORK",
            canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_METALWORKS"),
            category: "ものづくり",
            title: "板金加工体験",
            timeText: "14:00〜15:30",
            timeContextText: nil,
            locationName: "金属加工棟",
            systemImageName: "wrench.and.screwdriver"
        ),
        HomeEvent(
            id: "PREVIEW_EVENT_SPECIAL_VEHICLE",
            canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_OUTDOOR_YARD"),
            category: "機械",
            title: "特殊車両体験",
            timeText: "15:30〜16:30",
            timeContextText: nil,
            locationName: "屋外実習場",
            systemImageName: "gearshape",
            isCancelled: true,
            cancelNote: "雨天のため中止します"
        )
    ]
}

extension HomeClient {
    static func preview(
        result: HomeFetchResult,
        guidanceShortcuts: [HomeGuidanceShortcut] = HomePreviewFixtures.guidanceShortcuts
    ) -> HomeClient {
        HomeClient(
            fetch: {
                await Task.yield()
                return result
            },
            failureMessage: HomePreviewFixtures.failureMessage,
            guidanceShortcuts: { guidanceShortcuts }
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NexusAppShell(
                homeClient: .preview(result: .fresh(HomePreviewFixtures.loaded))
            )
                .previewDisplayName("通常・393×852")
                .previewDevice("iPhone 15 Pro")

            preview(state: .loading)
                .previewDisplayName("読込中")

            preview(state: .empty(HomePreviewFixtures.emptyMessage))
                .previewDisplayName("0件")

            preview(state: .failed(HomePreviewFixtures.failureMessage))
                .previewDisplayName("通信失敗")

            preview(
                state: .saved(HomePreviewFixtures.loaded, HomePreviewFixtures.savedMetadata)
            )
            .previewDisplayName("保存版")

            preview(state: .loaded(HomePreviewFixtures.loaded))
                .preferredColorScheme(.dark)
                .previewDisplayName("ダーク")

            preview(state: .loaded(HomePreviewFixtures.loaded))
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Dynamic Type・AXXXL")
        }
    }

    private static func preview(state: HomeViewState) -> some View {
        NavigationStack {
            HomeView(
                client: .preview(result: .fresh(HomePreviewFixtures.loaded)),
                initialState: state,
                onRouteRequest: { _ in }
            )
        }
    }
}
#endif
