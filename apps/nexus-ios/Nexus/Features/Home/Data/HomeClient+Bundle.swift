import Foundation

extension HomeClient {
    /// 保存済みの bundle のイベントから Home を作る（E2-5 改訂1 §3、#48）。
    ///
    /// - 次のイベント：中止でない、これから参加できる最も早い枠。
    /// - この後のイベント：これから参加できる枠を開始の早い順に。中止の枠も中止と分かる形で残す（EV-O1）。
    /// - お知らせは出さない（EV-D2）。
    ///
    /// 「これから参加できる」は、開始時刻に参加する枠（`atStart`）なら開始前、随時参加の枠（`anytime`）なら終了前。
    /// 保存済みの版がなければ失敗として throw し、0件（`.empty`）とは区別する。
    static func bundle(
        source: PublishedBundleSource,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> HomeClient {
        HomeClient(
            fetch: {
                guard let snapshot = try await source.current() else {
                    throw PublishedBundleSourceError.notAvailable
                }
                let catalog = BundleSpotCatalog(snapshot: snapshot)
                let upcoming = HomeEventProjection.upcoming(in: snapshot.bundle, catalog: catalog, now: now())
                guard !upcoming.isEmpty else {
                    return .empty(noUpcomingEventsMessage)
                }
                let homeSnapshot = HomeSnapshot(
                    nextEvent: upcoming.first { !$0.isCancelled },
                    upcomingEvents: Array(upcoming.prefix(HomeEventProjection.upcomingLimit))
                )
                if let saved = catalog.savedMetadata {
                    return .saved(homeSnapshot, SavedHomeMetadata(title: saved.title, detail: saved.detail))
                }
                return .fresh(homeSnapshot)
            },
            failureMessage: HomeStateMessage(
                title: "ホームを読み込めませんでした",
                detail: "通信状態を確認して、もう一度お試しください。",
                systemImageName: "wifi.slash"
            )
        )
    }

    static let noUpcomingEventsMessage = HomeStateMessage(
        title: "この後のイベントはありません",
        detail: "公開されているイベントは、すべて終了しています。",
        systemImageName: "calendar"
    )
}

/// bundle のイベントを Home の枠の一覧にする。日時はキャンパス現地時刻（JST）として読む（改訂1 §2）。
enum HomeEventProjection {
    /// 「この後のイベント」に出す最大件数。
    static let upcomingLimit = 10

    static func upcoming(in bundle: ParticipantBundle, catalog: BundleSpotCatalog, now: Date) -> [HomeEvent] {
        let categories = Dictionary(bundle.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let days = Dictionary(
            bundle.occurrences.flatMap(\.days).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let today = dateText(now)

        var items: [(start: Date, order: Int, event: HomeEvent)] = []
        for event in bundle.events {
            for slot in event.slots {
                guard let start = date(slot.date, slot.start), let end = date(slot.date, slot.end),
                      let firstVenue = slot.venues.first
                else {
                    // 時刻が読めない枠は推測で並べない。
                    continue
                }
                let isOpen = slot.participation == "anytime" ? end > now : start >= now
                guard isOpen else { continue }

                let day = days[slot.dayID]
                let dayCancelled = day?.status == "cancelled"
                let isCancelled = slot.status == "cancelled" || dayCancelled
                let venueName = catalog.spot(for: CanonicalSpotID(rawValue: firstVenue.spotID))?.name ?? firstVenue.spotID
                let others = slot.venues.count - 1

                let home = HomeEvent(
                    id: slot.id,
                    eventID: event.id,
                    canonicalSpotID: CanonicalSpotID(rawValue: firstVenue.spotID),
                    category: event.categoryID.flatMap { categories[$0] } ?? "イベント",
                    title: event.title,
                    timeText: "\(slot.start)〜\(slot.end)",
                    timeContextText: contextText(slot: slot, isToday: slot.date == today),
                    locationName: others > 0 ? "\(venueName) ほか\(others)か所" : venueName,
                    systemImageName: "calendar",
                    isCancelled: isCancelled,
                    cancelNote: slot.cancelNote ?? (dayCancelled ? day?.cancelNote : nil)
                )
                items.append((start, items.count, home))
            }
        }
        // 開始の早い順。同じ時刻は bundle の順（Studio の射影の順）。
        return items.sorted { ($0.start, $0.order) < ($1.start, $1.order) }.map(\.event)
    }

    /// 日付（今日でなければ）と、終日・随時参加の区別（EV-43）。
    private static func contextText(slot: ParticipantBundle.Event.Slot, isToday: Bool) -> String? {
        var parts: [String] = []
        if !isToday, let day = date(slot.date, "00:00") {
            parts.append(monthDayText(day))
        }
        if slot.timeMode == "allDay" {
            parts.append("終日")
        }
        if slot.participation == "anytime" {
            parts.append("随時参加")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    private static let campusTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP_POSIX")
        formatter.timeZone = campusTimeZone
        formatter.dateFormat = format
        return formatter
    }

    /// `YYYY-MM-DD` と `HH:mm`（JST）。読めなければ nil。
    static func date(_ day: String, _ time: String) -> Date? {
        formatter("yyyy-MM-dd HH:mm").date(from: "\(day) \(time)")
    }

    private static func dateText(_ date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    private static func monthDayText(_ date: Date) -> String {
        formatter("M月d日").string(from: date)
    }
}
