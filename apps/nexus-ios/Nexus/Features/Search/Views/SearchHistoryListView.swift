import SwiftUI

/// Figma `2575:2019` の「検索履歴」。
/// MapSearch の設計注記どおり、検索候補（サジェスト）は表示しない。履歴だけを出す。
struct SearchHistoryListView: View {
    let entries: [SearchQuery]
    let onSelect: (SearchQuery) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Text("検索履歴")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    VStack(spacing: 0) {
                        Button {
                            onSelect(entry)
                        } label: {
                            HStack(spacing: NexusTheme.spacing12) {
                                Image(systemName: "clock")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)

                                Text(historyLabel(for: entry))
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .nexusTappableRow()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("検索履歴、\(historyLabel(for: entry))")
                        .accessibilityHint("この条件で再検索します")

                        if index < entries.count - 1 {
                            Divider().accessibilityHidden(true)
                        }
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
