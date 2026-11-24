import SwiftUI

/// Figma `2575:2019` の「検索履歴」。
/// MapSearch の設計注記どおり、検索候補（サジェスト）は表示しない。履歴だけを出す。
struct SearchHistoryListView: View {
    private enum History {
        case queries([SearchQuery], (SearchQuery) -> Void)
        case spots([SpotSummary], (SpotSummary) -> Void)
    }

    private let history: History
    private let onClear: (() -> Void)?

    init(entries: [SearchQuery], onClear: (() -> Void)? = nil, onSelect: @escaping (SearchQuery) -> Void) {
        self.history = .queries(entries, onSelect)
        self.onClear = onClear
    }

    init(spots: [SpotSummary], onClear: @escaping () -> Void, onSelect: @escaping (SpotSummary) -> Void) {
        self.history = .spots(spots, onSelect)
        self.onClear = onClear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            HStack {
                Text("検索履歴")
                    .font(.footnote)
                    .foregroundStyle(Color(.secondaryLabel))
                    .accessibilityAddTraits(.isHeader)
                if let onClear {
                    Spacer()
                    Button(action: onClear) {
                        Text("履歴を消去")
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .frame(minHeight: NexusTheme.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            switch history {
            case .queries(let entries, let onSelect):
                queryRows(entries, onSelect: onSelect)
            case .spots(let spots, let onSelect):
                SearchSpotListView(spots: spots, onSelect: onSelect)
            }
        }
    }

    private func queryRows(_ entries: [SearchQuery], onSelect: @escaping (SearchQuery) -> Void) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                VStack(spacing: 0) {
                    Button {
                        onSelect(entry)
                    } label: {
                        HStack(spacing: NexusTheme.spacing12) {
                            Image(systemName: "clock")
                                .font(.footnote)
                                .foregroundStyle(Color(.secondaryLabel))
                                .accessibilityHidden(true)

                            Text(historyLabel(for: entry))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .nexusTappableRow()
                    }
                    .buttonStyle(.nexusPressableRow)
                    .accessibilityLabel("検索履歴、\(historyLabel(for: entry))")
                    .accessibilityHint("この条件で再検索します")

                    if index < entries.count - 1 {
                        Divider().accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func historyLabel(for entry: SearchQuery) -> String {
        guard let categoryID = entry.categoryID else { return entry.text }
        if entry.trimmedText.isEmpty {
            return categoryID.displayName
        }
        return "\(entry.text)（\(categoryID.displayName)）"
    }
}
