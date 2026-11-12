import Foundation

/// 画面が表示する bundle の版を1つに固定する（E2-5 §6 規則5、M1-7）。
///
/// 最初に読んだ時点の保存版を固定し、`advance()` が呼ばれるまで保存ポインタを読み直さない。
/// Map の地図・ピン・地点詳細・検索がすべて `source` から読むことで、旧版の地図に新版の詳細が
/// 混ざる状態を作らない。保存済みの版がない（nil）ことも、1つの表示状態として固定する。
actor PinnedBundleSource {
    private let upstream: PublishedBundleSource
    /// 固定中の版の読み込み。同時に読まれても上流は1回だけ読み、全員が同じ版を受け取る。
    private var pinned: Task<PublishedBundleSnapshot?, Error>?

    init(upstream: PublishedBundleSource) {
        self.upstream = upstream
    }

    /// 固定中の版を返す境界。`MapContentClient.bundle`・`SearchClient.bundle`・描画面に渡す。
    nonisolated var source: PublishedBundleSource {
        PublishedBundleSource(current: { try await self.current() })
    }

    func current() async throws -> PublishedBundleSnapshot? {
        if let pinned {
            return try await pinned.value
        }
        let upstream = self.upstream
        let task = Task { try await upstream.current() }
        pinned = task
        do {
            return try await task.value
        } catch {
            // 読めなかったことは固定しない。次に読むときに上流を読み直す。
            if pinned == task {
                pinned = nil
            }
            throw error
        }
    }

    /// 版の切替点（地点詳細を閉じた・Map タブを開き直した）で呼ぶ。
    ///
    /// 上流の最新の保存版が固定中の版と表示上違えば、それを固定し直して true を返す。
    /// 上流を読めなければ固定中の版を保ち、false を返す（表示中の版を失わない）。
    func advance() async -> Bool {
        let latest: PublishedBundleSnapshot?
        do {
            latest = try await upstream.current()
        } catch {
            return false
        }
        if case .success(let displayed)? = await pinnedResult(),
           Self.isSameDisplay(displayed, latest) {
            return false
        }
        pinned = Task { latest }
        return true
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
            return lhs.stored.metadata.bundleVersion == rhs.stored.metadata.bundleVersion
                && lhs.stored.metadata.sha256 == rhs.stored.metadata.sha256
                && lhs.isConfirmedLatest == rhs.isConfirmedLatest
                && lhs.lastConfirmedAt == rhs.lastConfirmedAt
        default:
            return false
        }
    }
}
