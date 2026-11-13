import XCTest
@testable import Nexus

/// Home の「詳細」から開いた地点詳細のイベント欄（#48、E2-5 改訂1 EV-O1・EV-09・EV-43）。
///
/// 実際の `MapContentClient.bundle` を通し、地点とイベントが同じ版から作られることを確かめる。
final class SpotEventProjectionTests: XCTestCase {
    private let spotID = CanonicalSpotID(rawValue: "mb_2f_cl_001")
    private let secondDayID = "0199b000-0000-7000-8000-000000000012"

    private func snapshot(_ object: [String: Any]) throws -> PublishedBundleSnapshot {
        let response = BundleFixtures.response(object)
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        let metadata = StoredBundleMetadata(
            bundleVersion: bundle.meta.bundleVersion,
            releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion,
            sha256: response.headers.sha256,
            byteLength: response.headers.byteLength,
            publishedAt: bundle.meta.publishedAt,
            etag: response.headers.etag,
            storedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        return PublishedBundleSnapshot(
            stored: StoredParticipantBundle(bundle: bundle, metadata: metadata),
            isConfirmedLatest: true,
            lastConfirmedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func detail(
        _ object: [String: Any],
        eventID: String? = BundleFixtures.eventID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> SpotDetailPresentation {
        let client = MapContentClient.bundle(source: .fixed(try snapshot(object)))
        guard case .fresh(let presentation) = try await client.spotDetail(spotID, eventID: eventID) else {
            XCTFail("fresh ではない", file: file, line: line)
            throw XCTSkip()
        }
        return presentation
    }

    private func published(_ presentation: SpotDetailPresentation, file: StaticString = #filePath, line: UInt = #line) throws -> SpotEventDetail {
        guard case .published(let event)? = presentation.event else {
            XCTFail("イベント欄がない: \(String(describing: presentation.event))", file: file, line: line)
            throw XCTSkip()
        }
        return event
    }

    /// 2日開催の bundle。2日目は `secondDayStatus` で中止にできる。
    private func twoDayObject(slots: [[String: Any]], secondDayStatus: String = "normal", secondDayNote: Any = NSNull()) -> [String: Any] {
        BundleFixtures.eventBundleObject(
            events: [BundleFixtures.event(description: "ドローンを操縦します", slots: slots)],
            days: [
                [
                    "id": BundleFixtures.dayID, "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00",
                    "status": "normal", "cancel_note": NSNull(),
                ],
                [
                    "id": secondDayID, "date": "2027-08-02", "public_start": "10:00", "public_end": "15:00",
                    "status": secondDayStatus, "cancel_note": secondDayNote,
                ],
            ]
        )
    }

    /// イベントが見つかれば、題名・カテゴリ・説明と全枠を日付・開始の早い順に出す。終わった枠も絞らない。
    func testFoundEventListsEverySlotInOrder() async throws {
        let object = twoDayObject(slots: [
            BundleFixtures.slot(id: "day2", dayID: secondDayID, date: "2027-08-02", start: "09:30", end: "10:00"),
            BundleFixtures.slot(id: "day1-late", start: "13:00", end: "13:45"),
            BundleFixtures.slot(id: "day1-early", start: "10:30", end: "11:15", venues: ["mb_2f_cl_001", "mb"]),
        ])
        let presentation = try await detail(object)
        let event = try published(presentation)

        XCTAssertEqual(presentation.summary.canonicalSpotID, spotID)
        XCTAssertEqual(event.title, "模擬授業")
        XCTAssertEqual(event.category, "体験授業")
        XCTAssertEqual(event.descriptionText, "ドローンを操縦します")
        XCTAssertEqual(event.slots.map(\.id), ["day1-early", "day1-late", "day2"])
        XCTAssertEqual(event.slots.map(\.dateText), ["8月1日", "8月1日", "8月2日"])
        XCTAssertEqual(event.slots[0].timeText, "10:30〜11:15")
        XCTAssertEqual(event.slots[0].venues.map(\.name), ["2A教室", "教室棟"])
        XCTAssertEqual(event.slots[0].venues.map(\.canonicalSpotID.rawValue), ["mb_2f_cl_001", "mb"])
        XCTAssertFalse(event.slots.contains(where: \.isCancelled))
    }

    /// 版にないイベント（取り下げ済みなど）は「掲載されていない」とし、別のイベントで代用しない。地点は出す。
    func testMissingEventIsReportedWithoutSubstitution() async throws {
        let presentation = try await detail(BundleFixtures.eventBundleObject(), eventID: "withdrawn-event")

        XCTAssertEqual(presentation.event, .notPublished(eventID: "withdrawn-event"))
        XCTAssertEqual(presentation.summary.displayName, "2A教室")
    }

    /// イベントを指定せずに開いた地点詳細にはイベント欄を出さない。
    func testNoEventIDMeansNoEventSection() async throws {
        let presentation = try await detail(BundleFixtures.eventBundleObject(), eventID: nil)
        XCTAssertNil(presentation.event)
    }

    /// 中止の枠は除かず、中止と案内文を持たせる（EV-O1）。
    func testCancelledSlotKeepsItsNote() async throws {
        let object = twoDayObject(slots: [
            BundleFixtures.slot(id: "cancelled", start: "10:00", end: "10:30", status: "cancelled", cancelNote: "雨天のため中止します"),
            BundleFixtures.slot(id: "normal", start: "11:00", end: "11:30"),
        ])
        let event = try published(try await detail(object))

        XCTAssertEqual(event.slots.map(\.id), ["cancelled", "normal"])
        XCTAssertTrue(event.slots[0].isCancelled)
        XCTAssertEqual(event.slots[0].cancelNote, "雨天のため中止します")
        XCTAssertFalse(event.slots[1].isCancelled)
        XCTAssertNil(event.slots[1].cancelNote)
    }

    /// 開催日が中止なら、その日の枠はすべて中止とし、開催日の案内を使う（EV-09）。別の日の枠は中止にしない。
    func testCancelledDayCancelsItsSlots() async throws {
        let object = twoDayObject(
            slots: [
                BundleFixtures.slot(id: "day1", start: "10:30", end: "11:15"),
                BundleFixtures.slot(id: "day2-a", dayID: secondDayID, date: "2027-08-02", start: "10:30", end: "11:15"),
                BundleFixtures.slot(
                    id: "day2-b", dayID: secondDayID, date: "2027-08-02", start: "12:00", end: "12:30",
                    status: "cancelled", cancelNote: "講師の都合により中止"
                ),
            ],
            secondDayStatus: "cancelled",
            secondDayNote: "台風のため2日目は中止します"
        )
        let event = try published(try await detail(object))

        XCTAssertEqual(event.slots.map(\.isCancelled), [false, true, true])
        XCTAssertNil(event.slots[0].cancelNote)
        XCTAssertEqual(event.slots[1].cancelNote, "台風のため2日目は中止します")
        // 枠の案内があれば、そちらを優先する（Home と同じ）。
        XCTAssertEqual(event.slots[2].cancelNote, "講師の都合により中止")
    }

    /// 終日の枠は「終日・随時参加」、時間指定で開始時に参加する枠は区別の文言なし（EV-43）。
    func testAllDayAndAnytimeText() async throws {
        var anytime = BundleFixtures.slot(id: "anytime", start: "13:00", end: "14:00")
        anytime["participation"] = "anytime"
        let object = twoDayObject(slots: [
            BundleFixtures.slot(id: "allDay", timeMode: "allDay", start: "10:00", end: "15:00", venues: ["mb"]),
            BundleFixtures.slot(id: "fixed", start: "10:30", end: "11:15"),
            anytime,
        ])
        let event = try published(try await detail(object))

        XCTAssertEqual(event.slots.map(\.id), ["allDay", "fixed", "anytime"])
        XCTAssertEqual(event.slots.map(\.modeText), ["終日・随時参加", nil, "随時参加"])
        XCTAssertEqual(event.slots[0].timeText, "10:00〜15:00")
    }
}
