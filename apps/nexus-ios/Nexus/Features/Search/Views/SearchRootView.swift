import SwiftUI

/// 探すタブ。Figma `2622:818`（初期）/ `2672:2046`（入力中）/ `2637:1512`（結果）は
/// 別画面ではなく同一画面の状態なので、1つの View が `SearchPhase` で切り替える。
struct SearchRootView: View {
    @Environment(\.appRouteRequestHandler) private var routeRequestHandler

    @Bindable var store: SearchStore
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing20) {
                header

                SearchFieldView(
                    text: $store.draftText,
                    isFocused: $isFieldFocused,
                    onSubmit: { Task { await store.submit() } },
                    onClear: { Task { await store.clearConditions() } }
                )

                SearchCategoryPickerView(
                    categories: availableCategories,
                    selection: store.committedQuery.categoryID,
                    onSelect: { category in
                        Task { await store.selectCategory(category) }
                    }
                )

                if let unresolvedCategoryID = store.unresolvedCategoryID {
                    unresolvedCategoryNotice(unresolvedCategoryID)
                }

                content
            }
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .task {
            await store.loadInitialIfNeeded()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
            Text("探す")
                .font(.largeTitle.bold())

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(100)
    }

    private var subtitleText: String {
        let trimmed = store.committedQuery.trimmedText
        if trimmed.isEmpty {
            return "行きたい教室や施設を探せます"
        }
        return "「\(trimmed)」の検索結果を表示しています"
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
            if store.phase == .focused && !store.historyEntries.isEmpty {
                SearchHistoryListView(entries: store.historyEntries) { entry in
                    Task { await store.selectHistoryEntry(entry) }
                }
            } else {
                SearchSpotListView(
                    headingText: snapshot.headingText,
                    totalCount: snapshot.totalCount,
                    spots: snapshot.spots,
                    onSelect: select
                )
            }

        case .results(let snapshot):
            SearchSpotListView(
                headingText: "検索結果",
                totalCount: snapshot.totalCount,
                spots: snapshot.spots,
                onSelect: select
            )

        case .empty(let message):
            VStack(spacing: NexusTheme.spacing12) {
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

                SearchSpotListView(
                    headingText: store.hasActiveConditions ? "検索結果" : "すべての地点",
                    totalCount: snapshot.totalCount,
                    spots: snapshot.spots,
                    onSelect: select
                )
            }
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
        routeRequestHandler(.spotDetails(canonicalSpotID: summary.canonicalSpotID))
    }
}
