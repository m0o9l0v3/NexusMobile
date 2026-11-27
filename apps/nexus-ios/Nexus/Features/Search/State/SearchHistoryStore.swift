import Foundation

/// 検索履歴（Figma `2575:2019` の「検索履歴」）。
///
/// Home と Map で検索語の履歴を共有し、Home で開いた地点の ID も保持する。
/// 端末内のみで保持し、個人プロファイルや行動追跡は追加しない（v04 P07 / P10）。
@MainActor
@Observable
final class SearchHistoryStore {
    private(set) var entries: [SearchQuery]
    private(set) var spotIDs: [CanonicalSpotID] = []
    let limit: Int

    init(entries: [SearchQuery] = [], limit: Int = 10) {
        self.limit = limit
        self.entries = Array(entries.prefix(limit))
    }

    /// 新しい順に積む。同一条件は重複させず先頭へ移す。
    /// 大小文字が違うクエリは別エントリとして扱う。
    func record(_ query: SearchQuery) {
        guard !query.isBlank else { return }
        var next = entries.filter { $0 != query }
        next.insert(query, at: 0)
        entries = Array(next.prefix(limit))
    }

    func recordSpot(_ id: CanonicalSpotID) {
        let recent = spotIDs.filter { $0 != id }
        spotIDs = Array(([id] + recent).prefix(limit))
    }

    func clear() {
        entries = []
        spotIDs = []
    }
}
