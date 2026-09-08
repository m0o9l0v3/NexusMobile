#if DEBUG
import Foundation
import SwiftUI

enum HomePreviewFixtures {
    static let loaded = HomeSnapshot(
        nextEvent: events[0],
        announcements: announcements,
        announcementBadgeCount: 3,
        featuredEvents: events
    )

    static let emptyMessage = HomeStateMessage(
        title: "表示できる体験イベントはありません",
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

    static let announcements = [
        HomeAnnouncement(
            id: "PREVIEW_ANNOUNCEMENT_DRONE",
            title: "ドローン体験の受付が開始されました",
            elapsedText: "5分前",
            canonicalSpotID: CanonicalSpotID(rawValue: "PREVIEW_MB_2A")
        ),
        HomeAnnouncement(
            id: "PREVIEW_ANNOUNCEMENT_LUNCH",
            title: "本日の昼食メニューが更新されました",
            elapsedText: "22分前",
            canonicalSpotID: nil
        )
    ]

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
            systemImageName: "gearshape"
        )
    ]
}

extension HomeClient {
    static func preview(result: HomeFetchResult) -> HomeClient {
        HomeClient(
            fetch: {
                await Task.yield()
                return result
            },
            failureMessage: HomePreviewFixtures.failureMessage
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
