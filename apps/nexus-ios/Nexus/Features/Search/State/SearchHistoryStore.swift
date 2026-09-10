import Foundation

/// 検索履歴（Figma `2575:2019` の「検索履歴」）。
///
/// 探すタブと Map の検索で**共有**する。履歴は共有が正しく、確定クエリは共有しない。
/// 端末内のみで保持し、個人プロファイルや行動追跡は追加しない（v04 P07 / P10）。
@MainActor
@Observable
final class SearchHistoryStore {
    private(set) var entries: [SearchQuery]
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

    func clear() {
        entries = []
    }
}
