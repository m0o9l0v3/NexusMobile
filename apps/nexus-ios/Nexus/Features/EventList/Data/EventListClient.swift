import Foundation

/// 「すべてのイベント」の取得境界。`HomeClient` と同じクロージャ構造体。
struct EventListClient: Sendable {
    var fetch: @Sendable () async throws -> EventListFetchResult
    var failureMessage: HomeStateMessage
}

extension EventListClient {
    static let unconfigured = EventListClient(
        fetch: { throw EventListClientError.notConfigured },
        failureMessage: HomeStateMessage(
            title: "イベントを読み込めませんでした",
            detail: "データ取得先の接続後に再試行してください。",
            systemImageName: "wifi.slash"
        )
    )

    /// 保存済みの bundle から、公開中のすべての枠を時間で絞らずに並べる（Home v1.0 下書き §2 C）。
    /// 「今日」の印が時刻で変わるため、Store は Home と同じ境界で読み直す。
    static func bundle(
        source: PublishedBundleSource,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> EventListClient {
        EventListClient(
            fetch: {
                guard let snapshot = try await source.current() else {
                    throw PublishedBundleSourceError.notAvailable
                }
                let catalog = BundleSpotCatalog(snapshot: snapshot)
                let saved = catalog.savedMetadata.map { SavedHomeMetadata(title: $0.title, detail: $0.detail) }
                let list = EventListProjection.snapshot(in: snapshot.bundle, catalog: catalog, now: now())
                guard !list.days.isEmpty else {
                    return .empty(noEventsMessage, saved: saved)
                }
                if let saved {
                    return .saved(list, saved)
                }
                return .fresh(list)
            },
            failureMessage: HomeStateMessage(
                title: "イベントを読み込めませんでした",
                detail: "通信状態を確認して、もう一度お試しください。",
                systemImageName: "wifi.slash"
            )
        )
    }

    /// 公開中のイベントが0件（Figma 未作成。下書き §4 質問7）。
    static let noEventsMessage = HomeStateMessage(
        title: "公開されているイベントはありません",
        detail: "イベントが公開されると、ここに一覧で表示します。",
        systemImageName: "calendar"
    )

    /// 選んだカテゴリの枠が0件（Figma 未作成。下書き §3）。
    static let noEventsInCategoryMessage = HomeStateMessage(
        title: "このカテゴリのイベントはありません",
        detail: "ほかのカテゴリか「すべて」を選んでください。",
        systemImageName: "line.3.horizontal.decrease.circle"
    )
}

private enum EventListClientError: Error {
    case notConfigured
}

/// bundle の枠を日ごとにまとめる。枠の読み方（時刻・会場・中止・カテゴリ）は Home と共通（`HomeEventProjection.slots`）。
enum EventListProjection {
    static func snapshot(in bundle: ParticipantBundle, catalog: BundleSpotCatalog, now: Date) -> EventListSnapshot {
        let today = HomeEventProjection.dateText(now)
        var days: [EventListDay] = []
        for item in HomeEventProjection.slots(in: bundle, catalog: catalog) {
            let row = EventListSlot(
                id: item.slot.id,
                eventID: item.eventID,
                canonicalSpotID: item.canonicalSpotID,
                categoryID: item.categoryID,
                categoryName: item.categoryName,
                title: item.title,
                startText: item.slot.start,
                endText: item.slot.end,
                modeText: HomeEventProjection.modeText(item.slot),
                locationName: item.locationName,
                isCancelled: item.isCancelled,
                cancelNote: item.cancelNote
            )
            // 並びは日付順なので、同じ日は続けて来る。
            if let last = days.last, last.id == item.slot.date {
                days[days.count - 1] = EventListDay(
                    id: last.id, title: last.title, isToday: last.isToday, slots: last.slots + [row]
                )
            } else {
                days.append(EventListDay(
                    id: item.slot.date,
                    title: HomeEventProjection.monthDayWeekdayText(item.start),
                    isToday: item.slot.date == today,
                    slots: [row]
                ))
            }
        }
        return EventListSnapshot(
            days: days,
            categories: bundle.categories.map { EventListCategory(id: $0.id, name: $0.name) }
        )
    }
}
