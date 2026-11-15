import SwiftUI

/// マップタブ。Figma `2539:12365`（通常）/ `2563:1628`・`2575:2019`（検索）/ `2639:1550`（地点詳細）。
///
/// 地図そのものは `MapSurfaceProvider` へ注入する。接続先が設定されていれば、
/// 公開された bundle を MapKit で描く（#26）。未設定なら未提供プレースホルダ。
struct MapRootView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    @Bindable var store: MapStore
    @Bindable var searchStore: SearchStore
    let routeStore: RouteRequestStore
    let surface: MapSurfaceProvider
    /// 現在地（#29）。nil なら現在地ボタンを出さない（プレビューなど）。
    var currentLocation: CurrentLocationStore?

    var body: some View {
        ZStack(alignment: .top) {
            surface.makeSurface(store.surfaceContext())
                .environment(\.mapSpotSelectionHandler) { spotID in
                    Task { await store.selectOnMap(spotID) }
                }
                .environment(\.mapContentRetryHandler) {
                    await store.mapContentRetried()
                }
                .environment(currentLocation)
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

                if let currentLocation, currentLocation.showsOffCampusNotice {
                    OffCampusNoticeView()
                        .accessibilitySortPriority(85)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)

                // 地図（MapKit の描画面）が出ているときだけ。地図データが無い未提供の表示には出さない。
                if let currentLocation, currentLocation.isMapShown {
                    HStack {
                        Spacer(minLength: 0)
                        CurrentLocationButton(store: currentLocation)
                    }
                    .accessibilitySortPriority(70)
                }

                detailContent
                    .accessibilitySortPriority(80)
            }
            .padding(.horizontal, NexusTheme.spacing16)
            .padding(.top, NexusTheme.spacing4)
            .padding(.bottom, NexusTheme.spacing16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(CurrentLocationFlowModifier(store: currentLocation))
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
                onRequestVenueRoute: requestRoute(for:),
                onDismiss: { Task { await store.clearSelection() } }
            )

        case .saved(let presentation, let metadata):
            SpotDetailCardView(
                presentation: presentation,
                savedMetadata: metadata,
                onRequestRoute: { requestRoute(for: presentation.summary.canonicalSpotID) },
                onRequestVenueRoute: requestRoute(for:),
                onDismiss: { Task { await store.clearSelection() } }
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

/// 現在地の権限フロー（#25 の説明シート・理由の表示）を Map に付け、権限の変化と構外の知らせを受け取る。
private struct CurrentLocationFlowModifier: ViewModifier {
    let store: CurrentLocationStore?

    func body(content: Content) -> some View {
        if let store {
            content
                .locationPermissionFlow(store.permission)
                // 位置情報オフ（#31）を現在地ボタンに出すため、Map を開いたら設定を読む。
                // 読むだけで、アプリの説明も OS のダイアログも出さない（#25 の決定 A）。
                .task { await store.permission.refresh() }
                .onChange(of: store.permission.state) { _, state in
                    store.permissionStateChanged(state)
                }
                // 「構内から離れています」が出たことを VoiceOver に伝える。
                .onChange(of: store.showsOffCampusNotice) { _, shows in
                    if shows {
                        AccessibilityNotification.Announcement(CurrentLocationAccessibilityText.offCampusTitle).post()
                    }
                }
        } else {
            content
        }
    }
}
