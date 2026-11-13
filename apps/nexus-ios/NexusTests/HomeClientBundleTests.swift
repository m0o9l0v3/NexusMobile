import XCTest
@testable import Nexus

/// bundle のイベントから Home を作る（E2-5 改訂1 §3、EV-D2・EV-D3・EV-O1、#48）。
///
/// 開催日は 2027-08-01、一般公開は 10:00–15:00（JST）。時刻は JST で指定する。
final class HomeClientBundleTests: XCTestCase {
    private let confirmedAt = Date(timeIntervalSince1970: 1_800_000_000)

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
            storedAt: confirmedAt
        )
        return PublishedBundleSnapshot(
            stored: StoredParticipantBundle(bundle: bundle, metadata: metadata),
            isConfirmedLatest: isConfirmedLatest,
            lastConfirmedAt: isConfirmedLatest ? confirmedAt : nil
        )
    }

    private func at(_ time: String, on day: String = "2027-08-01") -> Date {
        HomeEventProjection.date(day, time)!
    }

    private func fetch(_ object: [String: Any], now: String, isConfirmedLatest: Bool = true) async throws -> HomeFetchResult {
        let snapshot = try snapshot(object, isConfirmedLatest: isConfirmedLatest)
        let date = at(now)
        return try await HomeClient.bundle(source: .fixed(snapshot), now: { date }).fetch()
    }

    private func loaded(_ result: HomeFetchResult, file: StaticString = #filePath, line: UInt = #line) throws -> HomeSnapshot {
        guard case .fresh(let snapshot) = result else {
            XCTFail("fresh ではない: \(result)", file: file, line: line)
            throw XCTSkip()
        }
        return snapshot
    }

    private func slots(_ slots: [[String: Any]]) -> [String: Any] {
        BundleFixtures.eventBundleObject(events: [BundleFixtures.event(slots: slots)])
    }

    /// 開始の早い順に並べ、次のイベントは最も早い枠。終日の枠は開催日の時間と「終日・随時参加」を出す。
    func testUpcomingSlotsAreOrderedByStart() async throws {
        let home = try loaded(try await fetch(BundleFixtures.eventBundleObject(), now: "09:00"))

        XCTAssertEqual(home.upcomingEvents.map(\.timeText), ["10:00〜15:00", "10:30〜11:15"])
        XCTAssertEqual(home.nextEvent?.timeText, "10:00〜15:00")
        XCTAssertEqual(home.upcomingEvents[0].timeContextText, "終日・随時参加")
        XCTAssertNil(home.upcomingEvents[1].timeContextText)
        XCTAssertEqual(home.upcomingEvents[1].category, "体験授業")
        XCTAssertEqual(home.upcomingEvents[1].locationName, "2A教室")
        XCTAssertEqual(home.upcomingEvents[1].eventID, BundleFixtures.eventID)
    }

    /// 開始時刻に参加する枠は開始後に外れ、随時参加の枠は終了まで残る。
    func testStartedSlotsLeaveUnlessTheyAcceptAnytimeParticipation() async throws {
        let home = try loaded(try await fetch(BundleFixtures.eventBundleObject(), now: "10:45"))
        XCTAssertEqual(home.upcomingEvents.map(\.timeText), ["10:00〜15:00"])

        let ended = try await fetch(BundleFixtures.eventBundleObject(), now: "15:00")
        XCTAssertEqual(ended, .empty(HomeClient.noUpcomingEventsMessage))
    }

    /// 中止の枠は一覧に中止として残し、次のイベントには選ばない（EV-O1）。
    func testCancelledSlotsStayListedButAreNotTheNextEvent() async throws {
        let object = slots([
            BundleFixtures.slot(id: "early", start: "10:00", end: "10:30", status: "cancelled", cancelNote: "雨天のため中止します"),
            BundleFixtures.slot(id: "later", start: "11:00", end: "11:30"),
        ])
        let home = try loaded(try await fetch(object, now: "09:00"))

        XCTAssertEqual(home.upcomingEvents.map(\.id), ["early", "later"])
        XCTAssertTrue(home.upcomingEvents[0].isCancelled)
        XCTAssertEqual(home.upcomingEvents[0].cancelNote, "雨天のため中止します")
        XCTAssertEqual(home.nextEvent?.id, "later")
    }

    /// 開催日が中止なら、その日の枠はすべて中止として扱い、開催日の案内を出す。
    func testCancelledDayCancelsItsSlots() async throws {
        let object = BundleFixtures.eventBundleObject(days: [[
            "id": BundleFixtures.dayID, "date": "2027-08-01", "public_start": "10:00", "public_end": "15:00",
            "status": "cancelled", "cancel_note": "台風のため開催を中止します",
        ]])
        let home = try loaded(try await fetch(object, now: "09:00"))

        XCTAssertTrue(home.upcomingEvents.allSatisfy(\.isCancelled))
        XCTAssertEqual(home.upcomingEvents.first?.cancelNote, "台風のため開催を中止します")
        XCTAssertNil(home.nextEvent)
    }

    /// 今日でない枠には日付を付ける。複数の会場は「ほか」で数を示す。
    func testOtherDaysShowTheDateAndExtraVenuesAreCounted() async throws {
        let object = slots([BundleFixtures.slot(id: "s1", venues: ["mb_2f_cl_001", "mb"])])
        let snapshot = try snapshot(object)
        let dayBefore = at("12:00", on: "2027-07-31")
        let home = try loaded(try await HomeClient.bundle(source: .fixed(snapshot), now: { dayBefore }).fetch())

        XCTAssertEqual(home.upcomingEvents.first?.timeContextText, "8月1日")
        XCTAssertEqual(home.upcomingEvents.first?.locationName, "2A教室 ほか1か所")
    }

    func testBundleWithoutEventsIsEmptyNotFailure() async throws {
        let result = try await fetch(BundleFixtures.bundleObject(), now: "09:00")
        XCTAssertEqual(result, .empty(HomeClient.noUpcomingEventsMessage))
    }

    func testSavedBundleIsShownAsSaved() async throws {
        let result = try await fetch(BundleFixtures.eventBundleObject(), now: "09:00", isConfirmedLatest: false)
        guard case .saved(let home, let metadata) = result else {
            return XCTFail("saved ではない: \(result)")
        }
        XCTAssertEqual(home.upcomingEvents.count, 2)
        XCTAssertEqual(metadata.title, "保存版を表示しています")
    }

    func testMissingBundleIsAFailure() async {
        do {
            _ = try await HomeClient.bundle(source: .fixed(nil)).fetch()
            XCTFail("失敗するはず")
        } catch {
            XCTAssertEqual(error as? PublishedBundleSourceError, .notAvailable)
        }
    }
}
