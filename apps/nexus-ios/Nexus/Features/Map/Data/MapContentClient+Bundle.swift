import Foundation

extension MapContentClient {
    /// 保存済みの bundle から地点詳細を作る（#109、E2-5 §6）。
    ///
    /// - bundle 内の `spots[].id` との完全一致で引く。見つからなければ `unknownSpot` とし、
    ///   受付など別の地点へ置き換えない（E2-5 §5.3 の5）。
    /// - 保存済みの版がなければ失敗として throw する（0件・未掲載とは区別する）。
    static func bundle(source: PublishedBundleSource) -> MapContentClient {
        MapContentClient(
            spotDetail: { canonicalSpotID in
                guard let snapshot = try await source.current() else {
                    throw PublishedBundleSourceError.notAvailable
                }
                let catalog = BundleSpotCatalog(snapshot: snapshot)
                guard let spot = catalog.spot(for: canonicalSpotID) else {
                    return .unknownSpot(canonicalSpotID)
                }
                let presentation = SpotDetailPresentation(
                    summary: catalog.summary(for: spot),
                    descriptionText: spot.description
                )
                if let savedMetadata = catalog.savedMetadata {
                    return .saved(presentation, savedMetadata)
                }
                return .fresh(presentation)
            },
            failureMessage: MapContentClient.unconfigured.failureMessage
        )
    }
}
