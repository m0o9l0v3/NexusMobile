import SwiftUI

/// Figma `2723:2793` GuidanceDetail / FAQ ・ `2724:5710` Guidance/Detail/FAQ ・ `2722:5533` FAQ/Row。
///
/// 展開状態を VoiceOver が標準で読み上げる `DisclosureGroup` を使う。
/// 独自のボタン＋矢印には置き換えない。
struct GuidanceFAQArticleView: View {
    let article: GuidanceArticle

    /// Figma は「来場・受付」「困ったとき」のカテゴリ見出しでグループ化している。
    /// 出現順を保ったままグループ化する（辞書順に並べ替えない）。
    private var groups: [(category: String?, items: [GuidanceFAQItem])] {
        var order: [String?] = []
        var buckets: [String?: [GuidanceFAQItem]] = [:]
        for item in article.faqItems {
            if buckets[item.category] == nil {
                order.append(item.category)
                buckets[item.category] = []
            }
            buckets[item.category]?.append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        if article.faqItems.isEmpty {
            NexusStatusView(
                message: NexusStateMessage(
                    title: "よくある質問は未提供です",
                    detail: "正式な質問と回答が承認され次第、表示します。",
                    systemImageName: "questionmark.circle"
                )
            )
        } else {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                    if let category = group.category {
                        Text(category)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                    }

                    ForEach(group.items) { item in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                                ForEach(Array(item.answerParagraphs.enumerated()), id: \.offset) { _, paragraph in
                                    Text(paragraph)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, NexusTheme.spacing8)
                        } label: {
                            Text(item.question)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .nexusTappableRow()
                        }
                        .padding(.horizontal, NexusTheme.spacing16)
                        .padding(.vertical, NexusTheme.spacing8)
                        .nexusPanel(cornerRadius: NexusTheme.controlCornerRadius)
                    }
                }
            }

            GuidanceUpdateStatusView(status: article.updateStatus)
        }
    }
}
