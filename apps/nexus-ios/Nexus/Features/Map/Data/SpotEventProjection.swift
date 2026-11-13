import Foundation

/// bundle のイベント1件を地点詳細のイベント欄にする（#48、E2-5 改訂1 §2・EV-O1・EV-09・EV-43）。
///
/// Home の「この後のイベント」と違い、時刻で枠を絞らない。終わった枠も中止の枠も、そのイベントの
/// 全枠を出す。日時の読み方・終日と随時参加の文言は `HomeEventProjection` と同じものを使う。
enum SpotEventProjection {
    static func section(
        eventID: String,
        in bundle: ParticipantBundle,
        catalog: BundleSpotCatalog
    ) -> SpotEventSection {
        // ID の完全一致で引く。見つからなければ別のイベントで代用しない。
        guard let event = bundle.events.first(where: { $0.id == eventID }) else {
            return .notPublished(eventID: eventID)
        }
        let category = event.categoryID.flatMap { id in bundle.categories.first { $0.id == id }?.name } ?? "イベント"
        let days = Dictionary(
            bundle.occurrences.flatMap(\.days).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let ordered = event.slots.enumerated().sorted { lhs, rhs in
            (lhs.element.date, lhs.element.start, lhs.offset) < (rhs.element.date, rhs.element.start, rhs.offset)
        }
        let slots = ordered.map { _, slot in
            let day = days[slot.dayID]
            let dayCancelled = day?.status == "cancelled"
            return SpotEventSlot(
                id: slot.id,
                dateText: HomeEventProjection.date(slot.date, "00:00").map(HomeEventProjection.monthDayText) ?? slot.date,
                timeText: "\(slot.start)〜\(slot.end)",
                modeText: HomeEventProjection.modeText(slot),
                venues: slot.venues.map { venue in
                    let id = CanonicalSpotID(rawValue: venue.spotID)
                    return SpotEventVenue(
                        canonicalSpotID: id,
                        name: catalog.spot(for: id)?.name ?? venue.spotID,
                        note: venue.note
                    )
                },
                isCancelled: slot.status == "cancelled" || dayCancelled,
                // 枠の案内を優先し、なければ開催日の案内（Home と同じ）。
                cancelNote: slot.cancelNote ?? (dayCancelled ? day?.cancelNote : nil)
            )
        }

        return .published(SpotEventDetail(
            eventID: event.id,
            title: event.title,
            category: category,
            descriptionText: event.description,
            slots: slots
        ))
    }
}
