import SwiftUI

/// Figma `2555:1627` MapSearch。State=Collapsed / ExpandedEmpty / ExpandedHistory。
///
/// Figma の設計注記どおり、**検索候補は表示しない**。未検索時は検索対象の案内のみ、
/// 履歴がある場合は検索履歴のみを出す。
struct MapSearchPanelView: View {
    @Bindable var store: SearchStore
    @Binding var isExpanded: Bool
    @FocusState private var isFieldFocused: Bool
    let onSelect: (SpotSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            HStack(spacing: NexusTheme.spacing8) {
                SearchFieldView(
                    text: $store.draftText,
                    isFocused: $isFieldFocused,
                    onSubmit: { Task { await store.submit() } },
                    onClear: { Task { await store.clearConditions() } }
                )

                if isExpanded {
                    Button {
                        collapse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel("検索を閉じる")
                }
            }

            if isExpanded {
                expandedContent
            }
        }
        .padding(NexusTheme.spacing12)
        .nexusFloatingSurface(cornerRadius: 28)
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
                resultsList(snapshot.spots)
            }

        case .empty(let message):
            NexusStatusView(message: message)

        case .failed(let message):
            NexusStatusView(message: message) {
                Task { await store.retry() }
            }

        case .initial:
            if store.historyEntries.isEmpty {
                Text("教室名・施設名・イベント名で検索できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, NexusTheme.spacing8)
            } else {
                SearchHistoryListView(entries: store.historyEntries) { entry in
                    Task { await store.selectHistoryEntry(entry) }
                }
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
