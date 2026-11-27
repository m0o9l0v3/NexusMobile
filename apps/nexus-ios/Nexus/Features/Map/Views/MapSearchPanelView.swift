import SwiftUI

/// Figma `2555:1627` MapSearch。State=Collapsed / ExpandedEmpty / ExpandedHistory。
///
/// 閉じるボタンを検索欄に内包し、候補・履歴・状態を同じガラス面に連結する。
struct MapSearchPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var store: SearchStore
    @Binding var isExpanded: Bool
    @FocusState private var isFieldFocused: Bool
    let onSelect: (SpotSummary) -> Void

    var maxExpandedHeight: CGFloat? = nil
    var onRetry: (() async -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            VStack(spacing: 0) {
                SearchFieldView(
                    text: $store.draftText,
                    isFocused: $isFieldFocused,
                    onSubmit: { Task { await store.submit() } },
                    onClear: { Task { await store.clearConditions() } },
                    onClose: isExpanded ? collapse : nil
                )

                if isExpanded {
                    Divider()
                        .padding(.horizontal, NexusTheme.spacing16)
                    SearchPanelContentLayout(maxHeight: maxExpandedHeight) {
                        ViewThatFits(in: .vertical) {
                            expandedContent.fixedSize(horizontal: false, vertical: true)
                            ScrollView { expandedContent }
                        }
                    }
                    .padding(.horizontal, NexusTheme.spacing16)
                    .padding(.vertical, NexusTheme.spacing12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            .nexusFloatingGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: !isExpanded)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isExpanded)

#if DEBUG
            if !isExpanded, SearchCheckFixtures.scenario(arguments: ProcessInfo.processInfo.arguments) != nil {
                ViewThatFits(in: .horizontal) {
                    Text(SearchCheckFixtures.provisionalNotice).fixedSize()
                    Text("検証用の仮検索データ")
                }
                .font(.caption2)
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, NexusTheme.spacing12)
                .padding(.vertical, NexusTheme.spacing4)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityLabel(SearchCheckFixtures.provisionalNotice)
            }
#endif
        }
        .onChange(of: isFieldFocused) { _, focused in
            if focused {
                if !isExpanded { isExpanded = true }
                store.beginEditing()
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded, isFieldFocused {
                isFieldFocused = false
            }
        }
        .task {
            await store.loadInitialIfNeeded()
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 88)
                .accessibilityLabel("検索データを読み込み中")

        case .results(let snapshot):
            resultsList(snapshot.spots)

        case .saved(let snapshot, let metadata):
            VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                SavedContentBannerView(metadata: metadata)
                if store.hasActiveConditions {
                    resultsList(snapshot.spots)
                } else {
                    initialContent
                }
            }

        case .empty(let message, let saved):
            VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                if let saved {
                    SavedContentBannerView(metadata: saved)
                }
                NexusStatusView(message: message, showsCard: false)
                if store.hasActiveConditions {
                    Button("条件を解除する") {
                        Task { await store.clearConditions() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

        case .failed(let message):
            NexusStatusView(message: message, showsCard: false) {
                Task {
                    if let onRetry { await onRetry() } else { await store.retry() }
                }
            }

        case .initial:
            initialContent
        }
    }

    @ViewBuilder
    private var initialContent: some View {
        if store.historyEntries.isEmpty {
            Text("教室名・施設名・イベント名で検索できます。")
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, NexusTheme.spacing8)
        } else {
            SearchHistoryListView(entries: store.historyEntries) { entry in
                Task { await store.selectHistoryEntry(entry) }
            }
        }
    }

    private func resultsList(_ spots: [SpotSummary]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                SearchResultRowView(
                    summary: spot,
                    showsSeparator: index < spots.count - 1,
                    action: {
                        collapse()
                        onSelect(spot)
                    }
                )
            }
        }
    }

    private func collapse() {
        isFieldFocused = false
        isExpanded = false
        store.endEditing()
    }
}

/// 短い一覧には実寸を使い、長い一覧には親とパネルの上限の小さい方を提案する。
/// キーボードで高さが減ると ViewThatFits がスクロール表示を選び直す。
private struct SearchPanelContentLayout: Layout {
    let maxHeight: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var proposal = proposal
        if let maxHeight {
            proposal.height = min(proposal.height ?? maxHeight, maxHeight)
        }
        return subviews.first?.sizeThatFits(proposal) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}
