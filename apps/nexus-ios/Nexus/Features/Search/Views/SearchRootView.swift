import SwiftUI

/// Home の検索モード。Home と同じナビゲーションスタック内で表示する（Figma `2825:2195`）。
struct SearchRootView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var store: SearchStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                searchControls

                if let unresolvedCategoryID = store.unresolvedCategoryID {
                    unresolvedCategoryNotice(unresolvedCategoryID)
                }

#if DEBUG
                if SearchCheckFixtures.scenario(arguments: ProcessInfo.processInfo.arguments) != nil {
                    Text(SearchCheckFixtures.provisionalNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#endif
                content
            }
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.top, NexusTheme.spacing12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .task {
            await store.loadInitialIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .publishedBundleDisplayDidChange)) { _ in
            Task { await store.refreshAfterBundleUpdate() }
        }
        .onChange(of: store.draftText) { _, text in
            Task { await store.updateHomeResults(for: text) }
        }
        // ストアの局面を正とし、両方向で等価チェックしてから書く。
        // 無条件に書き戻すと初回打鍵を落とす。
        .onChange(of: store.phase) { _, newPhase in
            let shouldFocus = newPhase == .focused
            if isFieldFocused != shouldFocus {
                isFieldFocused = shouldFocus
            }
        }
        .onChange(of: isFieldFocused) { _, focused in
            guard store.isHomeSearchActive else { return }
            if focused {
                store.beginEditing()
            } else {
                store.endEditing()
            }
        }
        .onAppear {
            let shouldFocus = store.phase == .focused
            if isFieldFocused != shouldFocus {
                isFieldFocused = shouldFocus
            }
        }
    }

    /// 検索欄（✕ で閉じる）と絞り込みボタン。どちらも Liquid Glass なので1つのコンテナに入れる。
    /// コンテナの spacing を並びの間隔より小さくし、2つのガラスが溶け合わないようにする。
    @ViewBuilder
    private var searchControls: some View {
        NexusGlassContainer(spacing: NexusTheme.spacing8) {
            if dynamicTypeSize.prefersVerticalControls {
                VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                    searchField
                    filterMenu
                }
            } else {
                HStack(spacing: NexusTheme.spacing12) {
                    searchField
                    filterMenu
                }
            }
        }
    }

    private var searchField: some View {
        SearchFieldView(
            text: $store.draftText,
            surface: .home,
            isFocused: $isFieldFocused,
            onSubmit: { Task { await store.submit() } },
            onClear: { Task { await store.clearHomeSearchText() } },
            onClose: closeSearch
        )
    }

    private var filterMenu: some View {
        SearchCategoryFilterMenu(
            categories: availableCategories,
            selection: store.committedQuery.categoryID,
            onSelect: { category in
                Task { await store.selectCategory(category) }
            }
        )
    }

    private func closeSearch() {
        isFieldFocused = false
        store.cancelHomeSearch()
    }

    private var availableCategories: [SearchCategoryID] {
        if case .initial(let snapshot) = store.state {
            return snapshot.categories
        }
        return SearchCategoryID.allCases
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("検索データを読み込み中")

        case .initial(let snapshot):
            initialContent(snapshot.spots, heading: snapshot.headingText, totalCount: snapshot.totalCount)

        case .results(let snapshot):
            SearchSpotListView(spots: snapshot.spots, onSelect: select)

        case .empty(let message, let saved):
            VStack(spacing: NexusTheme.spacing12) {
                if let saved {
                    SavedContentBannerView(metadata: saved)
                }

                NexusStatusView(message: message)

                if store.hasActiveConditions {
                    Button("条件を解除する") {
                        Task { await store.clearConditions() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

        case .failed(let message):
            NexusStatusView(message: message) {
                Task { await store.retry() }
            }

        case .saved(let snapshot, let metadata):
            VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                SavedContentBannerView(metadata: metadata)

                if store.hasActiveConditions {
                    SearchSpotListView(spots: snapshot.spots, onSelect: select)
                } else {
                    initialContent(snapshot.spots, heading: "すべての地点", totalCount: snapshot.totalCount)
                }
            }
        }
    }

    @ViewBuilder
    private func initialContent(_ spots: [SpotSummary], heading: String, totalCount: Int) -> some View {
        let recentSpots = store.recentSpots(in: spots)
        if !recentSpots.isEmpty {
            SearchHistoryListView(spots: recentSpots, onClear: store.clearHistory, onSelect: select)
        } else if !store.historyEntries.isEmpty {
            SearchHistoryListView(entries: store.historyEntries, onClear: store.clearHistory) { entry in
                Task { await store.selectHistoryEntry(entry) }
            }
        } else {
            SearchSpotListView(headingText: heading, totalCount: totalCount, spots: spots, onSelect: select)
        }
    }

    private func unresolvedCategoryNotice(_ rawValue: String) -> some View {
        Label(
            "指定された種別「\(rawValue)」は取り扱いがないため、すべての種別を表示しています。",
            systemImage: "exclamationmark.triangle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NexusTheme.spacing12)
        .nexusPanel(NexusTheme.cautionSurface, cornerRadius: NexusTheme.controlCornerRadius)
    }

    /// 結果から Map の同一 canonical ID の地点詳細へ。ID は無加工で渡す。
    private func select(_ summary: SpotSummary) {
        isFieldFocused = false
        store.endEditing()
        store.recordSelectedSpot(summary)
        routeRequestHandler(.spotDetails(canonicalSpotID: summary.canonicalSpotID))
    }
}
