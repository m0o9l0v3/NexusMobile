import SwiftUI

/// マップタブ。Figma `2539:12365`（通常）/ `2563:1628`・`2575:2019`（検索）/ `2639:1550`（地点詳細）。
///
/// 地図そのものは `MapSurfaceProvider` へ注入する。接続先が設定されていれば、
/// 公開された bundle を MapKit で描く（#26）。未設定なら未提供プレースホルダ。
struct MapRootView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var routeCameraFitRevision = 0
    @State private var availableHeight: CGFloat = 0
    @State private var searchHeight: CGFloat = 0
    @State private var summaryHeight: CGFloat = 0

    private var reservesMapSpace: Bool {
        routeStore.activeRoute != nil && store.detailState == .none
    }

    private var maximumSummaryHeight: CGFloat? {
        guard availableHeight > 0 else { return nil }
        let fraction = typeSize >= .accessibility4 ? 0.35 : 0.48
        return max(0, availableHeight - searchHeight) * fraction
    }

    @Bindable var store: MapStore
    @Bindable var searchStore: SearchStore
    let routeStore: RouteRequestStore
    let surface: MapSurfaceProvider
    /// 現在地（#29）。nil なら現在地ボタンを出さない（プレビューなど）。
    var currentLocation: CurrentLocationStore?
    var routeOriginStore: ManualRouteOriginStore? = nil

    private var configuredOriginStore: ManualRouteOriginStore? {
        routeOriginStore?.isConfigured == true ? routeOriginStore : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            surface.makeSurface(store.surfaceContext(activeRoute: routeStore.activeRoute, routeCameraFitRevision: routeCameraFitRevision))
                .environment(\.mapSpotSelectionHandler) { spotID in
                    Task { await store.selectOnMap(spotID) }
                }
                .environment(\.mapContentRetryHandler) {
                    await store.mapContentRetried()
                }
                .environment(currentLocation)
                // MapKit の表示余白に検索欄と要約の実寸を伝え、背景地図はその背後にも描く。
                .safeAreaPadding(.top, reservesMapSpace ? searchHeight + NexusTheme.spacing8 : 0)
                .safeAreaPadding(.bottom, reservesMapSpace ? summaryHeight + NexusTheme.spacing16 : 0)
                .ignoresSafeArea(edges: reservesMapSpace ? [] : .bottom)
                .accessibilitySortPriority(10)

            VStack(spacing: NexusTheme.spacing12) {
                searchPanel
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { searchHeight = $0 }
                .accessibilitySortPriority(100)

                if let outcome = visibleOutcome {
                    routeNotice(for: outcome)
                        .accessibilitySortPriority(90)
                }

                if let route = routeStore.activeRoute, store.detailState != .none {
                    ActiveRouteBannerView(route: route) {
                        store.dismissDetailForRoute()
                        routeCameraFitRevision += 1
                    }
                    .accessibilitySortPriority(85)
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
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { summaryHeight = $0 }
                    .accessibilitySortPriority(80)
            }
            .padding(.horizontal, NexusTheme.spacing16)
            .padding(.top, NexusTheme.spacing4)
            .padding(.bottom, NexusTheme.spacing16)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
        .onChange(of: routeStore.activeRoute?.requestID) {
            if let route = routeStore.activeRoute {
                store.dismissDetailForRoute()
                AccessibilityNotification.Announcement(RouteAccessibilityText.started(route)).post()
            }
        }
        .onChange(of: routeStore.outcomeRevision) {
            if let outcome = routeStore.lastOutcome, let announcement = RouteAccessibilityText.announcement(for: outcome) {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(CurrentLocationFlowModifier(store: currentLocation))
        .sheet(item: Binding(get: { routeOriginStore?.session }, set: { session in
            if session == nil { routeOriginStore?.cancelSelection() }
        })) { _ in
            if let routeOriginStore {
                ManualRouteOriginSheetView(store: routeOriginStore)
                    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            }
        }
    }

    private var searchPanel: some View {
        VStack(spacing: NexusTheme.spacing8) {
            if routeStore.activeDestination?.savedMetadata != nil {
                Text("保存版（最新未確認）")
                    .font(.footnote.weight(.semibold))
                    .padding(NexusTheme.spacing8)
                    .nexusCard()
            }

            MapSearchPanelView(
                store: searchStore,
                isExpanded: $store.isSearchActive,
                onSelect: { summary in
                    Task { await store.select(
                        MapSelection(canonicalSpotID: summary.canonicalSpotID, eventID: nil, origin: .map)
                    ) }
                },
                maxExpandedHeight: availableHeight > 0 ? availableHeight * 0.55 : nil,
                onRetry: retrySearch
            )
        }
    }

    @ViewBuilder
    private func routeNotice(for outcome: RouteRequestOutcome) -> some View {
        let canRetry = outcome.allowsOriginSelectionRetry && routeStore.lastAttemptedDestination != nil
        let retryStore = canRetry ? configuredOriginStore : nil
        let title = outcome == .unavailable(RouteStateMessages.originRequired) ? "出発地を選ぶ" : "出発地を選び直す"
        let notice = RouteRequestNoticeView(
            outcome: outcome, onDismiss: routeStore.dismissNotice, actionTitle: title,
            onAction: retryStore.map { originStore in
                { Task { await originStore.beginOriginRetryForLastAttempt() } }
            }
        )
        if typeSize.isAccessibilitySize {
            // 長い理由と再選択ボタンを最後まで読めるよう、地点詳細とは別にスクロールする。
            ScrollView { notice.fixedSize(horizontal: false, vertical: true) }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: availableHeight > 0 ? availableHeight * 0.32 : nil)
        } else {
            notice
        }
    }

    private var visibleOutcome: RouteRequestOutcome? {
        if case .accepted(let destination) = routeStore.lastOutcome, destination.resolvedRoute != nil { return nil }
        return routeStore.lastOutcome
    }

    @ViewBuilder
    private var detailContent: some View {
        switch store.detailState {
        case .none:
            if let route = routeStore.activeRoute {
                let summary = RouteSummaryCardView(
                    route: route,
                    savedMetadata: routeStore.activeDestination?.savedMetadata,
                    onFitRoute: { routeCameraFitRevision += 1 },
                    onEndGuidance: {
                        routeOriginStore?.cancelSelection()
                        routeStore.endGuidance()
                        AccessibilityNotification.Announcement(RouteAccessibilityText.ended).post()
                    },
                    onChangeOrigin: configuredOriginStore.map { originStore in
                        { Task { await originStore.beginOriginChangeForActiveRoute() } }
                    }
                )
                ViewThatFits(in: .vertical) {
                    summary.fixedSize(horizontal: false, vertical: true)
                    ScrollView { summary }
                }
                .frame(maxHeight: maximumSummaryHeight, alignment: .bottom)
            }

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
                onRequestRoute: { previewRoute(to: .init(summary: presentation.summary)) },
                onRequestVenueRoute: { previewRoute(to: .init(id: $0.canonicalSpotID, displayName: $0.name)) },
                onChooseOrigin: configuredOriginStore.map { originStore in
                    { Task { await originStore.beginSelection(for: presentation.summary.canonicalSpotID, from: .map) } }
                },
                onDismiss: dismissDetail
            )

        case .saved(let presentation, let metadata):
            SpotDetailCardView(
                presentation: presentation,
                savedMetadata: metadata,
                onRequestRoute: { previewRoute(to: .init(summary: presentation.summary)) },
                onRequestVenueRoute: { previewRoute(to: .init(id: $0.canonicalSpotID, displayName: $0.name)) },
                onChooseOrigin: configuredOriginStore.map { originStore in
                    { Task { await originStore.beginSelection(for: presentation.summary.canonicalSpotID, from: .map) } }
                },
                onDismiss: dismissDetail
            )

        case .unknown(let canonicalSpotID):
            // 未知IDを受付など別地点へ置換しない。状態をそのまま示す。
            dismissibleStatus(
                message: NexusStateMessage(
                    title: "この地点は掲載されていません",
                    detail: "指定された地点ID「\(canonicalSpotID.rawValue)」は公開データに存在しません。別の地点へは切り替えません。",
                    systemImageName: "mappin.slash"
                )
            )

        case .failed(_, let message):
            dismissibleStatus(message: message) {
                Task { await store.retryDetail() }
            }
        }
    }

    private func retrySearch() async {
        let couldAdvance = store.canAdvanceSnapshot
        await searchStore.retry()
        // MapStore で再試行完了時にも確認し、途中で始まったプレビューや案内の版を保つ。
        if couldAdvance {
            await store.mapContentRetried()
        }
    }

    private func dismissibleStatus(message: NexusStateMessage, onRetry: (() -> Void)? = nil) -> some View {
        let body = VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            Text(message.title)
                .font(.headline)
            if let detail = message.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            if let onRetry {
                Button("再試行", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

        return VStack(spacing: NexusTheme.spacing12) {
            HStack {
                Image(systemName: message.systemImageName)
                    .font(.title2)
                    .foregroundStyle(Color(.secondaryLabel))
                    .accessibilityHidden(true)
                Spacer()
                Button(action: dismissDetail) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                        .contentShape(Circle())
                }
                .buttonStyle(.nexusPressableCircle)
                .accessibilityLabel("地点詳細を閉じる")
            }

            ViewThatFits(in: .vertical) {
                body
                ScrollView { body }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(NexusTheme.spacing20)
        .nexusFloatingSurface(cornerRadius: 24)
    }

    private func dismissDetail() {
        if routeStore.activeRoute != nil {
            store.dismissDetailForRoute()
        } else {
            Task { await store.clearSelection() }
        }
    }

    private func previewRoute(to target: RoutePreviewTarget) {
        routeRequestHandler(.routePreview(target))
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
