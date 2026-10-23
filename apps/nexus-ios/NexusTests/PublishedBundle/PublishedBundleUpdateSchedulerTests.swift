import XCTest
@testable import Nexus

/// 更新確認の時期（E2-5 §6 規則10）と接続先の読み込み（M1-3）。
final class PublishedBundleUpdateSchedulerTests: XCTestCase {

    /// 試験で進める時計。
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 1_793_523_600)

        var now: Date { lock.withLock { current } }

        func advance(by seconds: TimeInterval) {
            lock.withLock { current = current.addingTimeInterval(seconds) }
        }
    }

    /// 決めた順に結果を返す確認と、呼ばれた回数。
    private actor ScriptedChecks {
        private var outcomes: [PublishedBundleCheckOutcome]
        private(set) var count = 0

        init(_ outcomes: [PublishedBundleCheckOutcome]) {
            self.outcomes = outcomes
        }

        func next() -> PublishedBundleCheckOutcome {
            count += 1
            return outcomes.isEmpty ? .notPublished(recheckAfter: 300) : outcomes.removeFirst()
        }
    }

    /// 待たずに戻り、要求された待ち時間を記録する sleep。
    private actor SleepRecorder {
        private(set) var delays: [TimeInterval] = []

        func record(_ delay: TimeInterval) {
            delays.append(delay)
        }
    }

    private let succeeded = PublishedBundleCheckOutcome.notPublished(recheckAfter: 300)
    private let failed = PublishedBundleCheckOutcome.failed(.network, retryAfter: nil)

    private func makeScheduler(
        _ checks: ScriptedChecks,
        clock: Clock,
        sleeps: SleepRecorder = SleepRecorder(),
        random: Double = 0
    ) -> PublishedBundleUpdateScheduler {
        PublishedBundleUpdateScheduler(
            check: { await checks.next() },
            now: { clock.now },
            sleep: { delay in await sleeps.record(delay) },
            random: { random }
        )
    }

    // MARK: - 起動時と前面復帰時だけ確認する

    func testChecksOnLaunchAndOnlyAfterRecheckIntervalOnReturn() async {
        let clock = Clock()
        let checks = ScriptedChecks([succeeded, succeeded])
        let scheduler = makeScheduler(checks, clock: clock)

        await scheduler.becameActive()
        await scheduler.enteredBackground()
        clock.advance(by: 299)
        await scheduler.becameActive()
        var count = await checks.count
        XCTAssertEqual(count, 1, "最小間隔の前に前面へ戻っても確認しない")

        await scheduler.enteredBackground()
        clock.advance(by: 1)
        await scheduler.becameActive()
        count = await checks.count
        XCTAssertEqual(count, 2)
    }

    func testSuccessDoesNotScheduleAnyPolling() async {
        let scheduler = makeScheduler(ScriptedChecks([succeeded]), clock: Clock())

        await scheduler.becameActive()

        let pending = await scheduler.hasPendingRetry
        XCTAssertFalse(pending, "成功した後に定期的な確認を予約しない")
    }

    func testRecheckIntervalComesFromLatestResponse() async {
        let clock = Clock()
        let checks = ScriptedChecks([.updateRequired(recheckAfter: 3600)])
        let scheduler = makeScheduler(checks, clock: clock)

        await scheduler.becameActive()

        let next = await scheduler.nextCheckAt
        XCTAssertEqual(next, clock.now.addingTimeInterval(3600))
    }

    // MARK: - 失敗時の再試行

    func testFailuresBackOffExponentiallyUntilSuccess() async {
        let sleeps = SleepRecorder()
        let checks = ScriptedChecks([failed, failed, failed, succeeded])
        let scheduler = makeScheduler(checks, clock: Clock(), sleeps: sleeps, random: 0)

        await scheduler.becameActive()
        await scheduler.waitForPendingRetries()

        // jitter が0のとき、60・120・240 秒の上限の前半（30・60・120 秒）になる。
        let delays = await sleeps.delays
        XCTAssertEqual(delays, [30, 60, 120])
        let count = await checks.count
        XCTAssertEqual(count, 4)
    }

    func testBackoffAddsJitterAndIsCapped() async {
        let jittered = makeScheduler(ScriptedChecks([]), clock: Clock(), random: 0.5)
        let firstWithJitter = await jittered.backoffDelay(afterFailures: 1)
        XCTAssertEqual(firstWithJitter, 45)

        let maximal = makeScheduler(ScriptedChecks([]), clock: Clock(), random: 0.999_999)
        let capped = await maximal.backoffDelay(afterFailures: 20)
        XCTAssertLessThanOrEqual(capped, PublishedBundleUpdateScheduler.backoffMaxSeconds)
        XCTAssertGreaterThan(capped, PublishedBundleUpdateScheduler.backoffMaxSeconds / 2)
    }

    func testRetryAfterTakesPriorityOverBackoff() async {
        let sleeps = SleepRecorder()
        let checks = ScriptedChecks([.failed(.httpStatus(503), retryAfter: 120), succeeded])
        let scheduler = makeScheduler(checks, clock: Clock(), sleeps: sleeps)

        await scheduler.becameActive()
        await scheduler.waitForPendingRetries()

        let delays = await sleeps.delays
        XCTAssertEqual(delays, [120])
    }

    func testEnteringBackgroundCancelsRetryAndReturnRearmsRemainingWait() async {
        let clock = Clock()
        let checks = ScriptedChecks([.failed(.httpStatus(429), retryAfter: 600)])
        let scheduler = PublishedBundleUpdateScheduler(
            check: { await checks.next() },
            now: { clock.now },
            sleep: { _ in try await Task.sleep(nanoseconds: 60_000_000_000) },
            random: { 0 }
        )

        await scheduler.becameActive()
        var pending = await scheduler.hasPendingRetry
        XCTAssertTrue(pending)

        await scheduler.enteredBackground()
        pending = await scheduler.hasPendingRetry
        XCTAssertFalse(pending, "背面では再試行しない")

        // Retry-After の待ち時間の途中で前面に戻ったら、すぐには確認せず残りの時間で予約し直す。
        clock.advance(by: 100)
        await scheduler.becameActive()
        pending = await scheduler.hasPendingRetry
        XCTAssertTrue(pending)
        let count = await checks.count
        XCTAssertEqual(count, 1)
        await scheduler.enteredBackground()
    }

    // MARK: - 接続先（M1-3）

    func testConfigurationAcceptsOnlyCompleteHTTPURLs() {
        XCTAssertNil(NexusAPIConfiguration(rawValue: ""))
        // xcconfig で `//` 以降がコメントとして捨てられた値。
        XCTAssertNil(NexusAPIConfiguration(rawValue: "https:"))
        XCTAssertNil(NexusAPIConfiguration(rawValue: "nexus.example"))
        XCTAssertNil(NexusAPIConfiguration(rawValue: "ftp://nexus.example"))

        XCTAssertEqual(
            NexusAPIConfiguration(rawValue: " https://nexus.example ")?.bundleEndpoint.absoluteString,
            "https://nexus.example/api/v2/bundle"
        )
        XCTAssertEqual(
            NexusAPIConfiguration(rawValue: "https://nexus.example/")?.bundleEndpoint.absoluteString,
            "https://nexus.example/api/v2/bundle"
        )
    }

    func testConfigurationReadsInfoPlistKey() {
        XCTAssertNil(NexusAPIConfiguration(infoDictionary: nil))
        XCTAssertNil(NexusAPIConfiguration(infoDictionary: [NexusAPIConfiguration.infoPlistKey: ""]))
        XCTAssertEqual(
            NexusAPIConfiguration(infoDictionary: [NexusAPIConfiguration.infoPlistKey: "https://nexus.example"])?.baseURL,
            URL(string: "https://nexus.example")
        )
    }

    /// 生成された Info.plist に xcconfig の値を入れる項目がある（既定は空で、アプリは未接続のまま起動する）。
    func testAppInfoPlistHasAPIBaseURLKey() {
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: NexusAPIConfiguration.infoPlistKey) as? String)
    }
}
