import SwiftUI

/// Figma `2723:2793` GuidanceDetail / FAQ ・ `2724:5710` Guidance/Detail/FAQ ・ `2722:5533` FAQ/Row。
///
/// 展開状態を VoiceOver が標準で読み上げる `DisclosureGroup` を使う。
/// 独自のボタン＋矢印には置き換えない。
struct GuidanceFAQArticleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let article: GuidanceArticle
    @State private var expandedItemIDs: Set<String> = []

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
                VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                    if let category = group.category {
                        HStack(spacing: NexusTheme.spacing8) {
                            Image(systemName: "questionmark.bubble.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)

                            Text(category)
                                .font(.title3.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }

                    ForEach(group.items) { item in
                        faqDisclosureCard(item)
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: expandedItemIDs)
        }
    }

    private func faqDisclosureCard(_ item: GuidanceFAQItem) -> some View {
        let isExpanded = expandedItemIDs.contains(item.id)

        return DisclosureGroup(isExpanded: expansionBinding(for: item.id)) {
            VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                Divider()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                    ForEach(Array(item.answerParagraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, NexusTheme.spacing12)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Circle()
                        .fill(isExpanded ? Color.accentColor : NexusTheme.tintSurface)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Text("Q")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isExpanded ? NexusTheme.onAccent : Color.accentColor)
                        }
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                }

                Text(item.question)
                    .font(.body.weight(.semibold))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .nexusTappableRow()
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing12)
        .background(NexusTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isExpanded ? Color.accentColor.opacity(0.35) : NexusTheme.border,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .nexusElevation(.level1)
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedItemIDs.contains(id) },
            set: { shouldExpand in
                let update = {
                    if shouldExpand {
                        expandedItemIDs.insert(id)
                    } else {
                        expandedItemIDs.remove(id)
                    }
                }
                if reduceMotion {
                    update()
                } else {
                    withAnimation(.snappy(duration: 0.22)) {
                        update()
                    }
                }
            }
        )
    }
}
