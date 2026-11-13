#if DEBUG
import SwiftUI

/// Figma `2799:1665` と見比べるための検討用データ。イベント名・会場・理由はすべてサンプル。
enum EventListPreviewFixtures {
    static let categories = [
        EventListCategory(id: "PREVIEW_CATEGORY_A", name: "カテゴリA"),
        EventListCategory(id: "PREVIEW_CATEGORY_B", name: "カテゴリB"),
        EventListCategory(id: "PREVIEW_CATEGORY_C", name: "カテゴリC"),
    ]

    private static func slot(
        _ id: String, _ category: Int?, _ title: String, _ start: String, _ end: String, _ venue: String,
        mode: String? = nil, cancelNote: String? = nil, cancelled: Bool = false
    ) -> EventListSlot {
        EventListSlot(
            id: id,
            eventID: "PREVIEW_EVENT_\(id)",
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
            categoryID: category.map { categories[$0].id },
            categoryName: category.map { categories[$0].name },
            title: title,
            startText: start,
            endText: end,
            modeText: mode,
            locationName: venue,
            isCancelled: cancelled,
            cancelNote: cancelNote
        )
    }

    static let loaded = EventListSnapshot(
        days: [
            EventListDay(id: "2027-08-01", title: "8月1日（日）", isToday: true, slots: [
                slot("A", 0, "体験イベントA（サンプル）", "10:00", "10:45", "会場A（サンプル）"),
                slot("E", 1, "展示E（サンプル）", "10:00", "15:00", "会場E（サンプル）", mode: "終日"),
                slot("B", 0, "体験イベントB（サンプル）", "11:00", "11:45", "会場B（サンプル）"),
                slot("D", 2, "体験イベントD（サンプル）", "13:30", "14:00", "会場D（サンプル）",
                     cancelNote: "機材点検のため（サンプル）", cancelled: true),
            ]),
            EventListDay(id: "2027-08-02", title: "8月2日（月）", isToday: false, slots: [
                slot("C", 1, "見学C（サンプル）", "10:00", "15:00", "会場C（サンプル）", mode: "随時参加"),
                slot("F", 2, "体験イベントF（サンプル）", "10:30", "11:00", "会場F（サンプル）"),
            ]),
        ],
        categories: categories
    )
}

extension EventListClient {
    static func preview(result: EventListFetchResult) -> EventListClient {
        EventListClient(
            fetch: {
                await Task.yield()
                return result
            },
            failureMessage: HomePreviewFixtures.failureMessage
        )
    }
}

#Preview("すべてのイベント") {
    NavigationStack {
        EventListView(client: .preview(result: .fresh(EventListPreviewFixtures.loaded)))
    }
}

#Preview("保存版") {
    NavigationStack {
        EventListView(client: .preview(result: .saved(EventListPreviewFixtures.loaded, HomePreviewFixtures.savedMetadata)))
    }
}

#Preview("0件") {
    NavigationStack {
        EventListView(client: .preview(result: .empty(EventListClient.noEventsMessage)))
    }
}
#endif
