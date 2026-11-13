import Foundation

extension HomeClient {
    /// 保存済みの bundle のイベントから Home を作る（E2-5 改訂1 §3、#48）。
    ///
    /// - 次のイベント：中止でない、これから参加できる最も早い枠。
    /// - この後のイベント：これから参加できる枠を開始の早い順に。中止の枠も中止と分かる形で残す（EV-O1）。
    /// - 開催日カード：今日の開催日、なければこれから来る一番近い日、それもなければ最後の開催日（Home v1.0 下書き A）。
    /// - お知らせは出さない（EV-D2）。
    ///
    /// 「これから参加できる」は、開始時刻に参加する枠（`atStart`）なら開始前、随時参加の枠（`anytime`）なら終了前。
    /// 保存済みの版がなければ失敗として throw し、0件（`.empty`）とは区別する。
    /// 時刻で結果が変わるため、Store は再表示・前面復帰・bundle の確認後に読み直す（`HomeStore.refresh()`）。
    static func bundle(
        source: PublishedBundleSource,
        now: @escaping @Sendable () -> Date = { Date() },
        guidanceShortcuts: @escaping @Sendable () async -> [HomeGuidanceShortcut] = { [] }
    ) -> HomeClient {
        HomeClient(
            fetch: {
                guard let snapshot = try await source.current() else {
                    throw PublishedBundleSourceError.notAvailable
                }
                let catalog = BundleSpotCatalog(snapshot: snapshot)
                let saved = catalog.savedMetadata.map { SavedHomeMetadata(title: $0.title, detail: $0.detail) }
                let date = now()
                let upcoming = HomeEventProjection.upcoming(in: snapshot.bundle, catalog: catalog, now: date)
                let dayOverview = HomeDayOverviewProjection.overview(in: snapshot.bundle, now: date)
                guard !upcoming.isEmpty || dayOverview != nil else {
                    // 保存版の0件は、新しく公開されたイベントを確認できていない。保存版であることを伝える。
                    return .empty(noUpcomingEventsMessage, saved: saved)
                }
                // 開催日があれば、枠が残っていなくても開催日カードを出す（終了後は「終了」。枠の欄は空の表示）。
                let homeSnapshot = HomeSnapshot(
                    dayOverview: dayOverview,
                    nextEvent: upcoming.first { !$0.isCancelled },
                    upcomingEvents: Array(upcoming.prefix(HomeEventProjection.upcomingLimit))
                )
                if let saved {
                    return .saved(homeSnapshot, saved)
                }
                return .fresh(homeSnapshot)
            },
            failureMessage: HomeStateMessage(
                title: "ホームを読み込めませんでした",
                detail: "通信状態を確認して、もう一度お試しください。",
                systemImageName: "wifi.slash"
            ),
            guidanceShortcuts: guidanceShortcuts
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
        if let modeText = modeText(slot) {
            parts.append(modeText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    /// 終日・随時参加の区別（EV-43）。どちらでもなければ nil。地点詳細のイベント欄でも使う。
    static func modeText(_ slot: ParticipantBundle.Event.Slot) -> String? {
        var parts: [String] = []
        if slot.timeMode == "allDay" {
            parts.append("終日")
        }
        if slot.participation == "anytime" {
            parts.append("随時参加")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    static let campusTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    static func formatter(_ format: String) -> DateFormatter {
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

    static func dateText(_ date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    static func monthDayText(_ date: Date) -> String {
        formatter("M月d日").string(from: date)
    }
}

/// 開催日（`occurrences[].days[]`）を Home の開催日カードにする（Home v1.0 下書き §2 A）。日時は JST。
enum HomeDayOverviewProjection {
    static func overview(in bundle: ParticipantBundle, now: Date) -> HomeDayOverview? {
        let today = HomeEventProjection.dateText(now)
        // 日付が読めない開催日は推測で選ばない。
        let candidates = bundle.occurrences.flatMap { occurrence in
            occurrence.days.compactMap { day in
                HomeEventProjection.date(day.date, "00:00").map { (occurrence: occurrence, day: day, start: $0) }
            }
        }
        // `YYYY-MM-DD` は文字列の順が日付の順。
        let chosen = candidates.first { $0.day.date == today }
            ?? candidates.filter { $0.day.date > today }.min { $0.day.date < $1.day.date }
            ?? candidates.max { $0.day.date < $1.day.date }
        guard let chosen else { return nil }

        let day = chosen.day
        let (status, detail) = state(of: day, today: today, now: now)
        return HomeDayOverview(
            dayID: day.id,
            occurrenceName: chosen.occurrence.name,
            dateText: dateText(day),
            status: status,
            detailText: detail,
            cancelNote: status == .cancelled ? day.cancelNote : nil,
            otherDays: chosen.occurrence.days
                .filter { $0.id != day.id }
                .map { HomeOtherDay(id: $0.id, dateText: dateText($0), isCancelled: $0.status == "cancelled") }
        )
    }

    private static func state(
        of day: ParticipantBundle.Occurrence.Day,
        today: String,
        now: Date
    ) -> (HomeDayStatus, String?) {
        if day.status == "cancelled" {
            return (.cancelled, "この日の開催は中止になりました")
        }
        if day.date > today {
            return (.upcoming, daysUntil(day.date, today: today).map { "開催まであと\($0)日" })
        }
        if day.date < today {
            return (.ended, endedText)
        }
        guard let startText = day.publicStart, let endText = day.publicEnd,
              let start = HomeEventProjection.date(day.date, startText),
              let end = HomeEventProjection.date(day.date, endText)
        else {
            // 公開時間が未設定の当日は、開催前・開催中・終了を決められない。
            return (.today, nil)
        }
        if now < start {
            return (.upcoming, "\(startText)から公開します")
        }
        if now < end {
            return (.open, "\(endText)まで公開中です")
        }
        return (.ended, endedText)
    }

    private static let endedText = "この日の公開は終了しました"

    /// 「8月1日（日）10:00〜15:00」。公開時間が未設定なら日付だけ。
    static func dateText(_ day: ParticipantBundle.Occurrence.Day) -> String {
        guard let date = HomeEventProjection.date(day.date, "00:00") else { return day.date }
        let dayText = dayFormatter.string(from: date)
        guard let start = day.publicStart, let end = day.publicEnd else { return dayText }
        return "\(dayText)\(start)〜\(end)"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = HomeEventProjection.formatter("M月d日（E）")
        // 曜日を日本語で出すため、POSIX ではなく ja_JP にする。
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    private static func daysUntil(_ date: String, today: String) -> Int? {
        guard let target = HomeEventProjection.date(date, "00:00"),
              let base = HomeEventProjection.date(today, "00:00")
        else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HomeEventProjection.campusTimeZone
        return calendar.dateComponents([.day], from: base, to: target).day
    }
}
