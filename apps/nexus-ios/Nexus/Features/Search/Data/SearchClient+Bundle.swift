import Foundation

extension SearchClient {
    /// 保存済みの bundle の地点を検索する（#109、E2-5 §6）。
    ///
    /// 照合するのは表示名と `search_aliases` だけで、canonical ID には触れない（正規化もしない）。
    /// 保存済みの版がなければ失敗として throw し、0件（`.empty`）とは区別する。
    static func bundle(source: PublishedBundleSource) -> SearchClient {
        SearchClient(
            initialContent: {
                let catalog = try await catalog(from: source)
                let spots = catalog.allSpots.map(catalog.summary(for:))
                guard !spots.isEmpty else {
                    return .empty(noPublishedSpotsMessage, saved: catalog.savedMetadata)
                }
                let snapshot = SearchInitialSnapshot(headingText: "すべての地点", spots: spots)
                if let savedMetadata = catalog.savedMetadata {
                    return .saved(snapshot, savedMetadata)
                }
                return .fresh(snapshot)
            },
            search: { query in
                let catalog = try await catalog(from: source)
                let spots = catalog.allSpots
                    .filter { SpotNameMatcher.matches($0, text: query.trimmedText) }
                    .map(catalog.summary(for:))
                    .filter { summary in
                        query.categoryID.map { summary.kind?.rawValue == $0.rawValue } ?? true
                    }
                guard !spots.isEmpty else {
                    return .empty(noMatchMessage, saved: catalog.savedMetadata)
                }
                let snapshot = SearchResultsSnapshot(query: query, spots: spots)
                if let savedMetadata = catalog.savedMetadata {
                    return .saved(snapshot, savedMetadata)
                }
                return .fresh(snapshot)
            },
            failureMessage: SearchClient.unconfigured.failureMessage
        )
    }

    private static func catalog(from source: PublishedBundleSource) async throws -> BundleSpotCatalog {
        guard let snapshot = try await source.current() else {
            throw PublishedBundleSourceError.notAvailable
        }
        return BundleSpotCatalog(snapshot: snapshot)
    }

    static let noMatchMessage = NexusStateMessage(
        title: "該当する地点はありません",
        detail: "別の語で検索するか、条件を解除してください。",
        systemImageName: "magnifyingglass"
    )

    static let noPublishedSpotsMessage = NexusStateMessage(
        title: "掲載している地点はありません",
        detail: "地点の情報が公開されるまでお待ちください。",
        systemImageName: "mappin.slash"
    )
}

/// 地点名の照合（暫定）。
///
/// 正式な照合仕様（対象・別名・カテゴリ）は #27（#83 P12）で決める。ここでは、大文字小文字・
/// 全角半角・ひらがなとカタカナの違いを同一視した部分一致だけを行う。canonical ID は照合しない。
enum SpotNameMatcher {
    static func matches(_ spot: ParticipantBundle.Spot, text: String) -> Bool {
        let needle = normalize(text)
        guard !needle.isEmpty else { return true }
        return ([spot.name] + spot.searchAliases).contains { normalize($0).contains(needle) }
    }

    static func normalize(_ text: String) -> String {
        let katakana = text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        return katakana.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }
}
