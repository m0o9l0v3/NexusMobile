import Foundation

extension SearchClient {
    /// 保存済みの bundle の地点を検索する（#109、E2-5 §6）。
    ///
    /// 照合するのは表示名と `search_aliases` だけで、canonical ID には触れない（正規化もしない）。
    /// 未公開（404）と、版を取得・解釈できない状態を区別する。
    static func bundle(source: PublishedBundleSource) -> SearchClient {
        SearchClient(
            initialContent: {
                guard let catalog = try await catalog(from: source) else {
                    return .empty(noPublishedSpotsMessage, saved: nil)
                }
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
                guard let catalog = try await catalog(from: source) else {
                    return .empty(noPublishedSpotsMessage, saved: nil)
                }
                let needle = SpotNameMatcher.normalize(query.text)
                let spots = catalog.allSpots
                    .filter { SpotNameMatcher.matches($0, normalizedText: needle) }
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
            failureMessage: NexusStateMessage(
                title: "検索データを読み込めませんでした",
                detail: "通信できる場所で再試行してください。掲載が無いわけではありません。",
                systemImageName: "wifi.exclamationmark"
            ),
            updateRequiredMessage: appUpdateMessage,
            recheck: source.recheck
        )
    }

    private static func catalog(from source: PublishedBundleSource) async throws -> BundleSpotCatalog? {
        guard let snapshot = try await source.current() else {
            switch await source.absence() {
            case .notPublished: return nil
            case .updateRequired: throw PublishedBundleSourceError.updateRequired
            case .checkFailed, .unknown: throw PublishedBundleSourceError.notAvailable
            }
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

/// 表示名と検索別名を正規化して部分一致で照合する。地点詳細で使う ID の完全一致とは独立。
enum SpotNameMatcher {
    static func matches(_ spot: ParticipantBundle.Spot, normalizedText needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return ([spot.name] + spot.searchAliases).contains { normalize($0).contains(needle) }
    }

    static func normalize(_ text: String) -> String {
        let katakana = text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        return katakana.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
            .precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
