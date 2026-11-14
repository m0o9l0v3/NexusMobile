import Foundation

/// 画面が参照する bundle の1つの版と、その版が最新だと確認できているか。
///
/// 地点詳細・検索結果を「最新」と「保存版」に分けるのはこの値だけで決める。
/// 確認の状態（200・304 の成否）は取得クライアント（#109 の進め方3）が更新する。
struct PublishedBundleSnapshot: Equatable, Sendable {
    let stored: StoredParticipantBundle
    /// 直近の確認でこの版が最新だと分かっているか。false なら保存版として表示する。
    let isConfirmedLatest: Bool
    /// 最後に最新であることを確認できた日時（E2-5 §6 規則7）。一度も確認できていなければ nil。
    let lastConfirmedAt: Date?

    var bundle: ParticipantBundle { stored.bundle }
}

/// `MapContentClient`・`SearchClient` が bundle を読む境界。
///
/// 表示中の版の固定（E2-5 §6 規則5、M1-7）は、呼び出し側が同じ snapshot を返し続けることで行う。
/// ここでは保存ポインタを直接読まない。
struct PublishedBundleSource: Sendable {
    /// 保存済みの版がなければ nil。
    var current: @Sendable () async throws -> PublishedBundleSnapshot?
    /// `current` が nil を返したときの理由（#31）。未公開（掲載なし）と、確認できなかった（通信失敗など）を
    /// 分けるために使う。通信の失敗を0件・掲載なしとして表示しない。分からなければ `.unknown`。
    var absence: @Sendable () async -> PublishedBundleAbsence = { .unknown }
    /// 利用者の「再試行」で、すぐに1回確認する（#31）。確認の頻度はスケジューラが決めるので、
    /// 画面からはこの操作のときだけ呼ぶ。取得元を持たない構成では何もしない。
    var recheck: @Sendable () async -> Void = {}
}

/// 保存済みの版が無い理由（#31）。
enum PublishedBundleAbsence: Equatable, Sendable {
    /// まだ一度も公開されていない（404）。「掲載なし」として表示する（§4.3）。
    case notPublished
    /// 未知のメジャー版で読めない。アプリの更新が必要（§6 規則6）。
    case updateRequired
    /// 確認に失敗した（通信できない・検証や保存の失敗など）。0件ではない。
    case checkFailed
    /// 理由が分からない（まだ確認していない、取得元が理由を持たない）。0件とは扱わない。
    case unknown
}

extension PublishedBundleSource {
    /// 常に同じ snapshot を返す。試験と、画面の操作境界まで版を固定する呼び出し側で使う。
    static func fixed(_ snapshot: PublishedBundleSnapshot?, absence: PublishedBundleAbsence = .unknown) -> PublishedBundleSource {
        PublishedBundleSource(current: { snapshot }, absence: { absence })
    }
}

enum PublishedBundleSourceError: Error, Equatable {
    /// 保存済みの版がなく、表示できる地点データがない（0件ではなく取得できない状態）。
    case notAvailable
}
