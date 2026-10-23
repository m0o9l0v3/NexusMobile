import Foundation

/// bundle の更新を確認する時期を決める（E2-5 §6 規則10）。
///
/// - 確認するのは「起動時（最初に前面になったとき）」と「前面に戻ったときで、前回の確認から
///   最小間隔が経っている場合」だけで、定期的なポーリングをしない。
/// - 最小間隔は直近の応答の `Nexus-Recheck-After`（取得クライアントが 60〜3600 秒に収めた値）。
/// - 失敗したら1回だけ再試行を予約する。429・503 は `Retry-After` に従い、それ以外は指数バックオフに
///   ゆらぎ（jitter）を加える。背面に移ったら予約を取り消す。どの場合も保存済みの版を使い続ける。
actor PublishedBundleUpdateScheduler {
    /// 指数バックオフの初回と上限（秒）。仮の値で、当日の運用（#80 の実機検証を含む）で見直す。
    static let backoffBaseSeconds: TimeInterval = 60
    static let backoffMaxSeconds: TimeInterval = 3600
    /// 再試行までの待ち時間の範囲。`Retry-After` は信頼できない応答ヘッダーなので、極端な値をこの範囲に収める。
    static let retryDelayRange: ClosedRange<TimeInterval> = 1...backoffMaxSeconds

    private let check: @Sendable () async -> PublishedBundleCheckOutcome
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let random: @Sendable () -> Double

    private var isActive = false
    private var isChecking = false
    /// これより前は前面復帰でも確認しない。nil なら次に前面になったときに確認する。
    private(set) var nextCheckAt: Date?
    private var consecutiveFailures = 0
    private var retryTask: Task<Void, Never>?
    private(set) var lastOutcome: PublishedBundleCheckOutcome?

    init(
        check: @escaping @Sendable () async -> PublishedBundleCheckOutcome,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            // 範囲に収めてから変換する（大きな値で UInt64 への変換が実行時に止まらないように）。
            let clamped = min(max(seconds, 0), PublishedBundleUpdateScheduler.retryDelayRange.upperBound)
            try await Task.sleep(nanoseconds: UInt64(clamped * 1_000_000_000))
        },
        random: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.check = check
        self.now = now
        self.sleep = sleep
        self.random = random
    }

    /// 前面になった（起動時を含む）。最小間隔が経っていれば確認する。
    func becameActive() async {
        isActive = true
        guard retryTask == nil else { return }
        if let nextCheckAt, now() < nextCheckAt {
            // 失敗の後で背面に移って取り消した再試行は、残りの待ち時間で予約し直す。
            if consecutiveFailures > 0 {
                scheduleRetry(after: nextCheckAt.timeIntervalSince(now()))
            }
            return
        }
        await runCheck()
    }

    /// 背面に移った。予約した再試行を取り消す（背面では確認しない）。
    func enteredBackground() {
        isActive = false
        retryTask?.cancel()
        retryTask = nil
    }

    /// 予約した再試行が残っているか（試験用）。
    var hasPendingRetry: Bool { retryTask != nil }

    /// 予約した再試行がすべて終わるまで待つ（試験用）。
    func waitForPendingRetries() async {
        while let task = retryTask {
            await task.value
        }
    }

    private func runCheck() async {
        guard !isChecking else { return }
        isChecking = true
        let outcome = await check()
        isChecking = false
        lastOutcome = outcome
        apply(outcome)
    }

    private func apply(_ outcome: PublishedBundleCheckOutcome) {
        switch outcome {
        case .updated(_, let recheckAfter),
             .unchanged(_, let recheckAfter),
             .notPublished(let recheckAfter),
             .updateRequired(let recheckAfter):
            consecutiveFailures = 0
            nextCheckAt = now().addingTimeInterval(recheckAfter)
        case .failed(_, let retryAfter):
            consecutiveFailures += 1
            // Retry-After（429・503）は最小間隔より優先する。極端な値は範囲に収める。
            let requested = retryAfter ?? backoffDelay(afterFailures: consecutiveFailures)
            let delay = min(max(requested, Self.retryDelayRange.lowerBound), Self.retryDelayRange.upperBound)
            nextCheckAt = now().addingTimeInterval(delay)
            scheduleRetry(after: delay)
        }
    }

    /// 指数バックオフ（60, 120, 240 … 3600 秒）に、後半をゆらぎにする jitter を加える。
    func backoffDelay(afterFailures failures: Int) -> TimeInterval {
        let exponent = Double(max(failures - 1, 0))
        let ceiling = min(Self.backoffBaseSeconds * pow(2, exponent), Self.backoffMaxSeconds)
        return ceiling / 2 + random() * ceiling / 2
    }

    private func scheduleRetry(after delay: TimeInterval) {
        guard isActive else { return }
        retryTask?.cancel()
        let sleep = self.sleep
        retryTask = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            await self?.retryFired()
        }
    }

    private func retryFired() async {
        retryTask = nil
        guard isActive else { return }
        await runCheck()
    }
}
