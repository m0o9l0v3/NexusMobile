import SwiftUI

/// マップタブ。Figma `2539:12365`（通常）/ `2563:1628`・`2575:2019`（検索）/ `2639:1550`（地点詳細）。
///
/// 地図そのものは `MapSurfaceProvider` へ注入する。本番既定は未提供プレースホルダで、
/// MapKit も実座標も持たない（採用判断は #85 / #24）。
struct MapRootView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    @Bindable var store: MapStore
    @Bindable var searchStore: SearchStore
    let routeStore: RouteRequestStore
    let surface: MapSurfaceProvider

    var body: some View {
        ZStack(alignment: .top) {
            surface.makeSurface(store.surfaceContext())
                .ignoresSafeArea(edges: .bottom)
                .accessibilitySortPriority(10)

            VStack(spacing: NexusTheme.spacing12) {
                MapSearchPanelView(
                    store: searchStore,
                    isExpanded: $store.isSearchActive,
                    onSelect: { summary in
                        Task { await store.select(
                            MapSelection(
                                canonicalSpotID: summary.canonicalSpotID,
                                eventID: nil,
                                origin: .map
                            )
                        ) }
                    }
                )
                .accessibilitySortPriority(100)

                if let outcome = routeStore.lastOutcome {
                    RouteRequestNoticeView(outcome: outcome) {
                        routeStore.dismissNotice()
                    }
                    .accessibilitySortPriority(90)
                }

                Spacer(minLength: 0)

                detailContent
                    .accessibilitySortPriority(80)
            }
            .padding(.horizontal, NexusTheme.spacing16)
            .padding(.top, NexusTheme.spacing4)
            .padding(.bottom, NexusTheme.spacing16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch store.detailState {
        case .none:
            EmptyView()

        case .loading(let canonicalSpotID):
            HStack(spacing: NexusTheme.spacing12) {
                ProgressView()
                Text("地点情報を読み込み中")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NexusTheme.spacing20)
            .nexusFloatingSurface(cornerRadius: 24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("地点情報を読み込み中、\(canonicalSpotID.rawValue)")

        case .loaded(let presentation):
            SpotDetailCardView(
                presentation: presentation,
                savedMetadata: nil,
                onRequestRoute: { requestRoute(for: presentation.summary.canonicalSpotID) },
                onDismiss: { store.clearSelection() }
            )

        case .saved(let presentation, let metadata):
            SpotDetailCardView(
                presentation: presentation,
                savedMetadata: metadata,
                onRequestRoute: { requestRoute(for: presentation.summary.canonicalSpotID) },
                onDismiss: { store.clearSelection() }
            )

        case .unknown(let canonicalSpotID):
            // 未知IDを受付など別地点へ置換しない。状態をそのまま示す。
            NexusStatusView(
                message: NexusStateMessage(
                    title: "この地点は掲載されていません",
                    detail: "指定された地点ID「\(canonicalSpotID.rawValue)」は公開データに存在しません。別の地点へは切り替えません。",
                    systemImageName: "mappin.slash"
                )
            )

        case .failed(_, let message):
            NexusStatusView(message: message) {
                Task { await store.retryDetail() }
            }
        }
    }

    private func requestRoute(for canonicalSpotID: CanonicalSpotID) {
        routeRequestHandler(.route(destinationSpotID: canonicalSpotID))
    }
}
