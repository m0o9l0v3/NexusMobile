import Foundation

/// 画面が表示する bundle の版を1つに固定する（E2-5 §6 規則5、M1-7）。
///
/// 最初に読んだ版の内容を `advance()` まで固定する。確認日時と表示期限は固定中も確認する。
/// Map の地図・ピン・地点詳細・検索がすべて `source` から読むことで、旧版の地図に新版の詳細が
/// 混ざる状態を作らない。保存済みの版がない（nil）ことも、1つの表示状態として固定する。
actor PinnedBundleSource {
    enum DisplayUpdate: Sendable {
        case unchanged
        case refreshed(PublishedBundleSnapshot)
        case expired
    }

    private let upstream: PublishedBundleSource
    private let now: @Sendable () -> Date
    private var expiryNotice: PublishedBundleExpiryNotice?
    /// 固定中の版の読み込み。同時に読まれても上流は1回だけ読み、全員が同じ版を受け取る。
    private var pinned: Task<PublishedBundleSnapshot?, Error>?
    /// 直前の版切替。切替は1つずつ順に行う（後から始めた切替が先に新しい版を固定した後に、
    /// 先に始めた切替が遅れて古い版で固定し直さないため）。
    private var lastAdvance: Task<Bool, Never>?

    init(upstream: PublishedBundleSource, now: @escaping @Sendable () -> Date = { Date() }, notifiesExpiry: Bool = false) {
        self.upstream = upstream
        self.now = now
        expiryNotice = notifiesExpiry ? PublishedBundleExpiryNotice() : nil
    }

    /// 固定中の版を返す境界。`MapContentClient.bundle`・`SearchClient.bundle`・描画面に渡す。
    nonisolated var source: PublishedBundleSource {
        let upstream = self.upstream
        return PublishedBundleSource(
            current: { try await self.current() },
            absence: { await upstream.absence() },
            // 確認して新しい版を保存しても、固定中の版は変えない。切り替えは `advance()`（版の切替点）だけ。
            recheck: { await upstream.recheck() }
        )
    }

    func current() async throws -> PublishedBundleSnapshot? {
        let task = pinned ?? Task { try await upstream.current() }
        pinned = task
        let snapshot: PublishedBundleSnapshot?
        do {
            snapshot = try await task.value
        } catch {
            // 読めなかったことは固定しない。次に読むときに上流を読み直す。
            if pinned == task {
                pinned = nil
            }
            throw error
        }
        let date = now()
        if pinned == task { expiryNotice?.schedule(for: snapshot?.expiresAt, now: date) }
        return try snapshot?.usable(at: date)
    }

    /// 版は固定したまま、同じ内容が確認された日時と保存版の表示を更新する。
    /// 新しい版の確認・通信断で、固定中の版を「最新」と表示し続けない。
    func refreshConfirmation() async -> DisplayUpdate {
        guard let task = pinned, let displayed = try? await task.value else { return .unchanged }
        let latest = try? await upstream.current()
        guard pinned == task else { return .unchanged }
        let refreshed: PublishedBundleSnapshot
        if let latest, Self.isSameBundle(displayed, latest) {
            refreshed = latest
        } else {
            refreshed = PublishedBundleSnapshot(stored: displayed.stored, isConfirmedLatest: false,
                                                lastConfirmedAt: displayed.lastConfirmedAt)
        }
        let date = now()
        guard (try? refreshed.usable(at: date)) != nil else { return .expired }
        guard !Self.isSameDisplay(displayed, refreshed) else { return .unchanged }
        pin(refreshed)
        return .refreshed(refreshed)
    }

    /// 版の切替点（地点詳細を閉じた・Map タブを開き直した）で呼ぶ。
    ///
    /// 上流の最新の保存版が固定中の版と表示上違えば、それを固定し直して true を返す。
    /// 上流を読めなければ固定中の版を保ち、false を返す（表示中の版を失わない）。
    /// 重なって呼ばれたら、前の切替が終わってから上流を読む。
    func advance(onlyIfExpired: Bool = false) async -> Bool {
        let previous = lastAdvance
        let task = Task {
            _ = await previous?.value
            return await self.performAdvance(onlyIfExpired: onlyIfExpired)
        }
        lastAdvance = task
        return await task.value
    }

    private func performAdvance(onlyIfExpired: Bool) async -> Bool {
        let latest: PublishedBundleSnapshot?
        do {
            latest = try await upstream.current()
        } catch {
            return false
        }
        if case .success(let displayed)? = await pinnedResult() {
            if onlyIfExpired, let displayed, (try? displayed.usable(at: now())) != nil { return false }
            if Self.isSameDisplay(displayed, latest) { return false }
        }
        if onlyIfExpired, (try? latest?.usable(at: now())) == nil { return false }
        pin(latest)
        return true
    }

    private func pin(_ snapshot: PublishedBundleSnapshot?) {
        pinned = Task { snapshot }
        expiryNotice?.schedule(for: snapshot?.expiresAt, now: now())
    }

    private func pinnedResult() async -> Result<PublishedBundleSnapshot?, Error>? {
        guard let pinned else { return nil }
        do {
            return .success(try await pinned.value)
        } catch {
            return .failure(error)
        }
    }

    /// 同じ版で、保存版の表示（最新か・最終確認日時）も変わらないなら同じとみなす。
    /// bundle 本体は版と SHA-256 で同一性が決まるため、中身を比べない。
    static func isSameDisplay(_ lhs: PublishedBundleSnapshot?, _ rhs: PublishedBundleSnapshot?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return isSameBundle(lhs, rhs)
                && lhs.isConfirmedLatest == rhs.isConfirmedLatest
                && lhs.lastConfirmedAt == rhs.lastConfirmedAt
        default:
            return false
        }
    }

    private static func isSameBundle(_ lhs: PublishedBundleSnapshot, _ rhs: PublishedBundleSnapshot) -> Bool {
        lhs.stored.metadata.bundleVersion == rhs.stored.metadata.bundleVersion
            && lhs.stored.metadata.sha256 == rhs.stored.metadata.sha256
    }
}
