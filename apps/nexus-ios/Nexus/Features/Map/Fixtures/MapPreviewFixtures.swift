#if DEBUG
import SwiftUI

/// Preview／シミュレーター比較専用の検討用データ。正式な地点データではない。
enum MapPreviewFixtures {
    static let classroom2ADetail = SpotDetailPresentation(
        summary: SearchPreviewFixtures.classroom2A,
        descriptionText: "同じ地点の詳細をMapで表示しています"
    )

    static let savedMetadata = NexusSavedMetadata(
        title: "保存版の地点情報を表示しています",
        detail: "最新情報は確認できていません。"
    )

    static func detail(for canonicalSpotID: CanonicalSpotID) -> SpotDetailFetchResult {
        guard let summary = SearchPreviewFixtures.allSpots.first(
            where: { $0.canonicalSpotID == canonicalSpotID }
        ) else {
            // 未知IDは別地点へ置換しない。
            return .unknownSpot(canonicalSpotID)
        }
        return .fresh(
            SpotDetailPresentation(
                summary: summary,
                descriptionText: "同じ地点の詳細をMapで表示しています"
            )
        )
    }
}

extension MapContentClient {
    static func preview(
        result: (@Sendable (CanonicalSpotID) -> SpotDetailFetchResult)? = nil
    ) -> MapContentClient {
        MapContentClient(
            spotDetail: { canonicalSpotID in
                result?(canonicalSpotID) ?? MapPreviewFixtures.detail(for: canonicalSpotID)
            },
            failureMessage: MapContentClient.unconfigured.failureMessage
        )
    }
}

extension MapSurfaceProvider {
    /// 検討用の描画面。方眼と注記だけを描き、地図に見せない。
    static let preview = MapSurfaceProvider(identifier: "preview-grid") { context in
        AnyView(PreviewMapSurfaceView(context: context))
    }
}

private struct PreviewMapSurfaceView: View {
    let context: MapSurfaceContext

    var body: some View {
        ZStack {
            NexusTheme.surface

            Canvas { canvasContext, size in
                let step: CGFloat = 40
                var path = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                canvasContext.stroke(path, with: .color(.secondary.opacity(0.18)), lineWidth: 1)
            }

            VStack(spacing: NexusTheme.spacing4) {
                Text("検討用の表示面")
                    .font(.headline)
                Text("本番の構内地図ではありません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let focusedSpotID = context.focusedSpotID {
                    Text(focusedSpotID.rawValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("検討用の表示面。本番の構内地図ではありません。")
    }
}

@MainActor
private func previewMapStore(
    client: MapContentClient = .preview(),
    selection: MapSelection? = nil,
    detailState: MapSpotDetailState = .none
) -> MapStore {
    MapStore(client: client, initialSelection: selection, initialDetailState: detailState)
}

@MainActor
private func previewMapSearchStore() -> SearchStore {
    SearchStore(
        client: .preview(),
        history: SearchHistoryStore(entries: [
            SearchQuery(text: "第1体育館"),
            SearchQuery(text: "航空工学科"),
            SearchQuery(text: "ドローン体験"),
        ]),
        surface: .map,
        initialState: .initial(SearchPreviewFixtures.initialSnapshot)
    )
}

#Preview("マップ・通常（地図未提供）") {
    NavigationStack {
        MapRootView(
            store: previewMapStore(),
            searchStore: previewMapSearchStore(),
            routeStore: RouteRequestStore(handler: .unconfigured),
            surface: .unavailable
        )
    }
}

#Preview("マップ・地点詳細 mb_f2_cr_2a") {
    NavigationStack {
        MapRootView(
            store: previewMapStore(
                selection: MapSelection(
                    canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
                    eventID: nil,
                    origin: .search
                ),
                detailState: .loaded(MapPreviewFixtures.classroom2ADetail)
            ),
            searchStore: previewMapSearchStore(),
            routeStore: RouteRequestStore(handler: .unconfigured),
            surface: .preview
        )
    }
}

#Preview("マップ・未知ID") {
    NavigationStack {
        MapRootView(
            store: previewMapStore(
                selection: MapSelection(
                    canonicalSpotID: CanonicalSpotID(rawValue: "unknown_spot_id"),
                    eventID: nil,
                    origin: .search
                ),
                detailState: .unknown(CanonicalSpotID(rawValue: "unknown_spot_id"))
            ),
            searchStore: previewMapSearchStore(),
            routeStore: RouteRequestStore(handler: .unconfigured),
            surface: .preview
        )
    }
}

#Preview("マップ・保存版") {
    NavigationStack {
        MapRootView(
            store: previewMapStore(
                selection: MapSelection(
                    canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
                    eventID: nil,
                    origin: .map
                ),
                detailState: .saved(
                    MapPreviewFixtures.classroom2ADetail,
                    MapPreviewFixtures.savedMetadata
                )
            ),
            searchStore: previewMapSearchStore(),
            routeStore: RouteRequestStore(handler: .unconfigured),
            surface: .preview
        )
    }
}

#Preview("マップ・ダーク") {
    NavigationStack {
        MapRootView(
            store: previewMapStore(),
            searchStore: previewMapSearchStore(),
            routeStore: RouteRequestStore(handler: .unconfigured),
            surface: .unavailable
        )
    }
    .preferredColorScheme(.dark)
}
#endif
