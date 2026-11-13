import XCTest
@testable import Nexus

/// 「すべてのイベント」の射影（Home v1.0 下書き §2 C・§3）。開催日は 2027-08-01 / 08-02、時刻は JST。
final class EventListProjectionTests: XCTestCase {
    private let dayTwo = "0199b000-0000-7000-8000-000000000012"
    private let otherCategory = "0199b000-0000-7000-8000-000000000002"

    private func snapshot(_ object: [String: Any], isConfirmedLatest: Bool = true) throws -> PublishedBundleSnapshot {
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
            isConfirmedLatest: isConfirmedLatest,
            lastConfirmedAt: isConfirmedLatest ? Date(timeIntervalSince1970: 1_800_000_000) : nil
        )
    }

    private func fetch(
        _ object: [String: Any],
        now: String = "12:00",
        on date: String = "2027-08-01",
        isConfirmedLatest: Bool = true
    ) async throws -> EventListFetchResult {
        let snapshot = try snapshot(object, isConfirmedLatest: isConfirmedLatest)
        let at = HomeEventProjection.date(date, now)!
        return try await EventListClient.bundle(source: .fixed(snapshot), now: { at }).fetch()
    }

    private func loaded(_ result: EventListFetchResult, file: StaticString = #filePath, line: UInt = #line) throws -> EventListSnapshot {
        guard case .fresh(let snapshot) = result else {
            XCTFail("fresh ではない: \(result)", file: file, line: line)
            throw XCTSkip()
        }
        return snapshot
    }

    /// 2日間・2カテゴリ・カテゴリなし・中止を含む bundle。
    private var twoDayObject: [String: Any] {
        BundleFixtures.eventBundleObject(
            events: [
                BundleFixtures.event(id: "0199b000-0000-7000-8000-000000000100", title: "模擬授業", slots: [
                    BundleFixtures.slot(id: "d1-late", start: "13:00", end: "13:30"),
                    BundleFixtures.slot(id: "d2-early", dayID: dayTwo, date: "2027-08-02", start: "10:00", end: "10:30"),
                    BundleFixtures.slot(id: "d1-cancel", start: "11:00", end: "11:30", status: "cancelled", cancelNote: "機材点検のため"),
                ]),
                BundleFixtures.event(
                    id: "0199b000-0000-7000-8000-000000000200", title: "展示", categoryID: otherCategory,
                    slots: [BundleFixtures.slot(id: "d1-allday", timeMode: "allDay", start: "10:00", end: "15:00", venues: ["mb"])]
                ),
                BundleFixtures.event(
                    id: "0199b000-0000-7000-8000-000000000300", title: "説明会", categoryID: NSNull(),
                    slots: [BundleFixtures.slot(id: "d1-early", start: "09:30", end: "10:00")]
                ),
            ],
            categories: [
                ["id": BundleFixtures.categoryID, "name": "体験授業"],
                ["id": otherCategory, "name": "展示"],
            ],
            days: [
                ["id": BundleFixtures.dayID, "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00",
                 "status": "normal", "cancel_note": NSNull()],
                ["id": dayTwo, "date": "2027-08-02", "public_start": "10:00", "public_end": "15:00",
                 "status": "normal", "cancel_note": NSNull()],
            ]
        )
    }

    /// 時間で絞らず、日付 → 開始の早い順。終わった枠も残す。
    func testAllSlotsAreGroupedByDayInStartOrder() async throws {
        let list = try loaded(try await fetch(twoDayObject, now: "16:00"))

        XCTAssertEqual(list.days.map(\.id), ["2027-08-01", "2027-08-02"])
        XCTAssertEqual(list.days.map(\.title), ["8月1日（日）", "8月2日（月）"])
        XCTAssertEqual(list.days[0].slots.map(\.id), ["d1-early", "d1-allday", "d1-cancel", "d1-late"])
        XCTAssertEqual(list.days[1].slots.map(\.id), ["d2-early"])
    }

    func testTodayIsMarkedInJST() async throws {
        let list = try loaded(try await fetch(twoDayObject, now: "00:10", on: "2027-08-02"))
        XCTAssertEqual(list.days.map(\.isToday), [false, true])
    }

    func testRowShowsTimesCategoryVenueAndMode() async throws {
        let list = try loaded(try await fetch(twoDayObject))
        let allDay = try XCTUnwrap(list.days[0].slots.first { $0.id == "d1-allday" })

        XCTAssertEqual(allDay.startText, "10:00")
        XCTAssertEqual(allDay.endText, "15:00")
        XCTAssertEqual(allDay.categoryName, "展示")
        XCTAssertEqual(allDay.modeText, "終日・随時参加")
        XCTAssertEqual(allDay.eventID, "0199b000-0000-7000-8000-000000000200")

        let late = try XCTUnwrap(list.days[0].slots.first { $0.id == "d1-late" })
        XCTAssertEqual(late.locationName, "2A教室")
        XCTAssertNil(late.modeText)
        XCTAssertEqual(late.canonicalSpotID.rawValue, "mb_2f_cl_001")
    }

    /// 中止の枠は残し、中止と理由を持つ（EV-O1）。
    func testCancelledSlotStaysWithItsNote() async throws {
        let list = try loaded(try await fetch(twoDayObject))
        let cancelled = try XCTUnwrap(list.days[0].slots.first { $0.id == "d1-cancel" })
        XCTAssertTrue(cancelled.isCancelled)
        XCTAssertEqual(cancelled.cancelNote, "機材点検のため")
    }

    /// 開催日が中止なら、その日の枠はすべて中止として残し、開催日の理由を出す（EV-09）。
    func testCancelledDayCancelsAllItsSlots() async throws {
        let object = BundleFixtures.eventBundleObject(days: [[
            "id": BundleFixtures.dayID, "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00",
            "status": "cancelled", "cancel_note": "台風のため",
        ]])
        let list = try loaded(try await fetch(object))
        XCTAssertEqual(list.days[0].slots.count, 2)
        XCTAssertTrue(list.days[0].slots.allSatisfy(\.isCancelled))
        XCTAssertEqual(list.days[0].slots.first?.cancelNote, "台風のため")
    }

    // MARK: - カテゴリの絞り込み

    func testCategoryFilterKeepsOnlyMatchingSlotsAndDropsEmptyDays() async throws {
        let list = try loaded(try await fetch(twoDayObject))

        XCTAssertEqual(list.categories.map(\.name), ["体験授業", "展示"])
        let exhibit = list.days(in: otherCategory)
        XCTAssertEqual(exhibit.map(\.id), ["2027-08-01"])
        XCTAssertEqual(exhibit[0].slots.map(\.id), ["d1-allday"])
        XCTAssertEqual(list.summaryText(in: otherCategory), "展示：1件（開始時刻順・中止の枠も表示）")
    }

    /// カテゴリなしの枠は「すべて」でだけ出て、カテゴリ名を持たない。
    func testUncategorisedSlotsAppearOnlyInAll() async throws {
        let list = try loaded(try await fetch(twoDayObject))
        let early = try XCTUnwrap(list.days[0].slots.first { $0.id == "d1-early" })
        XCTAssertNil(early.categoryID)
        XCTAssertNil(early.categoryName)
        XCTAssertFalse(list.days(in: BundleFixtures.categoryID).flatMap(\.slots).contains { $0.id == "d1-early" })
        XCTAssertEqual(list.summaryText(in: nil), "すべて：5件（開始時刻順・中止の枠も表示）")
    }

    func testCategoryWithoutSlotsIsEmpty() async throws {
        let object = BundleFixtures.eventBundleObject(categories: [
            ["id": BundleFixtures.categoryID, "name": "体験授業"],
            ["id": otherCategory, "name": "展示"],
        ])
        let list = try loaded(try await fetch(object))
        XCTAssertEqual(list.days(in: otherCategory), [])
        XCTAssertEqual(list.summaryText(in: otherCategory), "展示：0件（開始時刻順・中止の枠も表示）")
    }

    // MARK: - 0件・保存版・失敗

    func testBundleWithoutEventsIsEmpty() async throws {
        let result = try await fetch(BundleFixtures.bundleObject())
        XCTAssertEqual(result, .empty(EventListClient.noEventsMessage))
    }

    func testSavedBundleIsShownAsSaved() async throws {
        let result = try await fetch(twoDayObject, isConfirmedLatest: false)
        guard case .saved(let list, let metadata) = result else {
            return XCTFail("saved ではない: \(result)")
        }
        XCTAssertEqual(list.days.count, 2)
        XCTAssertEqual(metadata.title, "保存版を表示しています")
    }

    func testSavedEmptyKeepsSavedMetadata() async throws {
        let result = try await fetch(BundleFixtures.bundleObject(), isConfirmedLatest: false)
        guard case .empty(_, let saved?) = result else {
            return XCTFail("保存版の0件ではない: \(result)")
        }
        XCTAssertEqual(saved.title, "保存版を表示しています")
    }

    func testMissingBundleIsAFailure() async {
        do {
            _ = try await EventListClient.bundle(source: .fixed(nil)).fetch()
            XCTFail("失敗するはず")
        } catch {
            XCTAssertEqual(error as? PublishedBundleSourceError, .notAvailable)
        }
    }
}
