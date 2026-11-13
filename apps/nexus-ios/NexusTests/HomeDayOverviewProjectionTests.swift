import XCTest
@testable import Nexus

/// 開催日カードの射影（Home v1.0 下書き §2 A・§3、Figma `2790:1744`）。時刻は JST。
final class HomeDayOverviewProjectionTests: XCTestCase {
    private let dayOne = "0199b000-0000-7000-8000-000000000011"
    private let dayTwo = "0199b000-0000-7000-8000-000000000012"

    private func day(
        id: String,
        date: String,
        start: Any = "10:00",
        end: Any = "15:00",
        status: String = "normal",
        cancelNote: Any = NSNull()
    ) -> [String: Any] {
        [
            "id": id, "date": date, "public_start": start, "public_end": end,
            "status": status, "cancel_note": cancelNote,
        ]
    }

    private func bundle(days: [[String: Any]]) throws -> ParticipantBundle {
        // 枠はどちらの開催日にも置かない（開催日だけを見る）。
        let object = BundleFixtures.eventBundleObject(events: [], days: days)
        let response = BundleFixtures.response(object)
        return try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
    }

    private func overview(days: [[String: Any]], now time: String, on date: String = "2027-08-01") throws -> HomeDayOverview? {
        HomeDayOverviewProjection.overview(in: try bundle(days: days), now: HomeEventProjection.date(date, time)!)
    }

    func testNoDaysMeansNoCard() throws {
        XCTAssertNil(try overview(days: [], now: "09:00"))
    }

    // MARK: - 状態の境界

    func testBeforePublicStartOnTheDayIsUpcoming() throws {
        let card = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "09:59"))
        XCTAssertEqual(card.status, .upcoming)
        XCTAssertEqual(card.detailText, "10:00から公開します")
        XCTAssertEqual(card.dateText, "8月1日（日）10:00〜15:00")
    }

    func testFromPublicStartUntilPublicEndIsOpen() throws {
        let atStart = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "10:00"))
        XCTAssertEqual(atStart.status, .open)
        XCTAssertEqual(atStart.detailText, "15:00まで公開中です")

        let beforeEnd = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "14:59"))
        XCTAssertEqual(beforeEnd.status, .open)
    }

    func testAtPublicEndIsEnded() throws {
        let card = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "15:00"))
        XCTAssertEqual(card.status, .ended)
        XCTAssertEqual(card.detailText, "この日の公開は終了しました")
    }

    func testDaysBeforeTheDayCountDown() throws {
        let card = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "23:59", on: "2027-07-29"))
        XCTAssertEqual(card.status, .upcoming)
        XCTAssertEqual(card.detailText, "開催まであと3日")
    }

    /// JST の日付で数える（UTC では前日の 15:00 以降が当日になる）。
    func testCampusDateIsJST() throws {
        // 2027-08-01 00:30 JST は UTC では 7月31日。
        let card = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "00:30"))
        XCTAssertEqual(card.status, .upcoming)
        XCTAssertEqual(card.detailText, "10:00から公開します")
    }

    // MARK: - 中止

    func testCancelledDayWinsOverTime() throws {
        let days = [day(id: dayOne, date: "2027-08-01", status: "cancelled", cancelNote: "台風のため")]
        let card = try XCTUnwrap(try overview(days: days, now: "12:00"))
        XCTAssertEqual(card.status, .cancelled)
        XCTAssertEqual(card.detailText, "この日の開催は中止になりました")
        XCTAssertEqual(card.cancelNote, "台風のため")
    }

    func testCancelledDayWithoutNote() throws {
        let days = [day(id: dayOne, date: "2027-08-01", status: "cancelled")]
        let card = try XCTUnwrap(try overview(days: days, now: "12:00"))
        XCTAssertEqual(card.status, .cancelled)
        XCTAssertNil(card.cancelNote)
    }

    // MARK: - 公開時間が未設定

    func testNullPublicHoursShowDateOnly() throws {
        let days = [day(id: dayOne, date: "2027-08-01", start: NSNull(), end: NSNull())]
        let today = try XCTUnwrap(try overview(days: days, now: "12:00"))
        XCTAssertEqual(today.dateText, "8月1日（日）")
        XCTAssertEqual(today.status, .today)
        XCTAssertNil(today.detailText)

        let before = try XCTUnwrap(try overview(days: days, now: "12:00", on: "2027-07-31"))
        XCTAssertEqual(before.status, .upcoming)
        XCTAssertEqual(before.detailText, "開催まであと1日")

        let after = try XCTUnwrap(try overview(days: days, now: "12:00", on: "2027-08-02"))
        XCTAssertEqual(after.status, .ended)
    }

    // MARK: - どの日を出すか・ほかの開催日

    func testPicksTodayThenNextThenLast() throws {
        let days = [day(id: dayOne, date: "2027-08-01"), day(id: dayTwo, date: "2027-08-08")]

        XCTAssertEqual(try overview(days: days, now: "16:00", on: "2027-08-01")?.dayID, dayOne)
        XCTAssertEqual(try overview(days: days, now: "16:00", on: "2027-08-01")?.status, .ended)
        XCTAssertEqual(try overview(days: days, now: "09:00", on: "2027-08-03")?.dayID, dayTwo)
        XCTAssertEqual(try overview(days: days, now: "09:00", on: "2027-07-01")?.dayID, dayOne)

        let afterAll = try XCTUnwrap(try overview(days: days, now: "09:00", on: "2027-09-01"))
        XCTAssertEqual(afterAll.dayID, dayTwo)
        XCTAssertEqual(afterAll.status, .ended)
    }

    func testOtherDaysOfTheSameOccurrenceAreListed() throws {
        let days = [
            day(id: dayOne, date: "2027-08-01"),
            day(id: dayTwo, date: "2027-08-02", status: "cancelled", cancelNote: "設備点検"),
        ]
        let card = try XCTUnwrap(try overview(days: days, now: "09:00", on: "2027-07-29"))
        XCTAssertEqual(card.dayID, dayOne)
        XCTAssertEqual(card.otherDays, [
            HomeOtherDay(id: dayTwo, dateText: "8月2日（月）10:00〜15:00", isCancelled: true)
        ])
    }

    func testSingleDayHasNoOtherDays() throws {
        let card = try XCTUnwrap(try overview(days: [day(id: dayOne, date: "2027-08-01")], now: "09:00"))
        XCTAssertEqual(card.otherDays, [])
    }
}
