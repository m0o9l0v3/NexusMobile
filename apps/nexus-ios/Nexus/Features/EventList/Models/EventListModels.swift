import Foundation

/// 「すべてのイベント」の1行 = 1つの枠（Home v1.0 下書き §2 C、Figma `EventListHIG/SlotRow`）。
struct EventListSlot: Identifiable, Equatable, Sendable {
    let id: String
    let eventID: String
    let canonicalSpotID: CanonicalSpotID
    /// カテゴリなしの枠は nil。カテゴリ名の行を出さない。
    let categoryID: String?
    let categoryName: String?
    let title: String
    let startText: String
    let endText: String
    /// 「終日」「随時参加」（`HomeEventProjection.modeText`）。
    let modeText: String?
    let locationName: String
    /// 枠または開催日が中止。行は残し、経路の操作を出さない（EV-O1）。
    let isCancelled: Bool
    let cancelNote: String?
}

/// 日ごとのまとまり。
struct EventListDay: Identifiable, Equatable, Sendable {
    /// `YYYY-MM-DD`（JST）。
    let id: String
    /// 「8月1日（日）」。
    let title: String
    let isToday: Bool
    let slots: [EventListSlot]
}

struct EventListCategory: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

struct EventListSnapshot: Equatable, Sendable {
    /// 日付 → 開始の早い順。
    let days: [EventListDay]
    /// 絞り込みに出すカテゴリ（`categories[]` の順）。
    let categories: [EventListCategory]

    /// カテゴリで絞った日ごとのまとまり。nil は「すべて」。枠が0件になった日は外す。
    /// カテゴリなしの枠は「すべて」でだけ出る。
    func days(in categoryID: String?) -> [EventListDay] {
        guard let categoryID else { return days }
        return days.compactMap { day in
            let slots = day.slots.filter { $0.categoryID == categoryID }
            return slots.isEmpty ? nil : EventListDay(id: day.id, title: day.title, isToday: day.isToday, slots: slots)
        }
    }

    /// 「すべて：6件（開始時刻順・中止の枠も表示）」。
    func summaryText(in categoryID: String?) -> String {
        let name = categoryID.flatMap { id in categories.first { $0.id == id }?.name } ?? "すべて"
        let count = days(in: categoryID).reduce(0) { $0 + $1.slots.count }
        return "\(name)：\(count)件（開始時刻順・中止の枠も表示）"
    }
}

enum EventListFetchResult: Equatable, Sendable {
    case fresh(EventListSnapshot)
    /// 公開中の枠が0件。保存版から作った0件なら `saved` を持つ。
    case empty(HomeStateMessage, saved: SavedHomeMetadata? = nil)
    case saved(EventListSnapshot, SavedHomeMetadata)
}

enum EventListViewState: Equatable, Sendable {
    case idle
    case loading
    case loaded(EventListSnapshot)
    case empty(HomeStateMessage, saved: SavedHomeMetadata? = nil)
    case failed(HomeStateMessage)
    case saved(EventListSnapshot, SavedHomeMetadata)
}
