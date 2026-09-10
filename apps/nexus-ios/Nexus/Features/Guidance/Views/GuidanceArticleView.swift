import SwiftUI

/// 案内詳細。Figma の5画面はレイアウトを `GuidanceArticleKind` で選ぶ。
/// 記事IDによる分岐は本番コードに置かない。
///
/// - `.standard`   `2723:2622` GuidanceDetail / Standard
/// - `.help`       `2723:2675` GuidanceDetail / Help
/// - `.helpHealth` `2723:2824` GuidanceDetail / Help Health
/// - `.access`     `2723:2729` GuidanceDetail / Access
/// - `.faq`        `2723:2793` GuidanceDetail / FAQ
struct GuidanceArticleView: View {
    let articleID: GuidanceArticleID
    let store: GuidanceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing20) {
                content
            }
            .padding(.horizontal, NexusTheme.spacing20)
            .padding(.top, NexusTheme.spacing16)
            .padding(.bottom, 36)
        }
        .background(Color(.systemBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadArticleIfNeeded(articleID)
        }
    }

    private var navigationTitle: String {
        switch store.articleState(for: articleID) {
        case .loaded(let article), .saved(let article, _):
            return article.navigationTitle
        case .idle, .loading, .failed, .notProvided:
            return "案内"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.articleState(for: articleID) {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
                .accessibilityLabel("案内を読み込み中")

        case .loaded(let article):
            GuidanceArticleBodyView(article: article, savedMetadata: nil)

        case .saved(let article, let metadata):
            GuidanceArticleBodyView(article: article, savedMetadata: metadata)

        case .notProvided(let requestedID):
            // 他の記事へフォールバックしない。何が未提供かをそのまま示す。
            NexusStatusView(
                message: NexusStateMessage(
                    title: "この案内の原稿は未提供です",
                    detail: "記事ID「\(requestedID.rawValue)」の正式原稿が承認され次第、表示します。",
                    systemImageName: "doc.text"
                )
            )

        case .failed(let message):
            NexusStatusView(message: message) {
                Task { await store.retryArticle(articleID) }
            }
        }
    }
}

/// 記事本文。共通部品（見出し・更新状況・記事セクション・関連地点）を種類ごとに組み替える。
private struct GuidanceArticleBodyView: View {
    let article: GuidanceArticle
    let savedMetadata: NexusSavedMetadata?

    var body: some View {
        if let savedMetadata {
            SavedContentBannerView(metadata: savedMetadata)
        }

        if let highlight = article.highlight {
            GuidanceHighlightCardView(highlight: highlight)
                .accessibilitySortPriority(100)
        } else {
            VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                Text(article.title)
                    .font(.largeTitle.bold())

                if let subtitle = article.subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(100)
        }

        switch article.kind {
        case .standard, .help, .helpHealth:
            GuidanceUpdateStatusView(status: article.updateStatus)

            ForEach(article.sections) { section in
                GuidanceArticleSectionView(section: section)
            }

            GuidanceRelatedPlaceView(
                places: article.relatedPlaces,
                unresolvedNote: article.unresolvedRelatedPlaceNote
            )

        case .access:
            GuidanceAccessArticleView(article: article)

        case .faq:
            GuidanceFAQArticleView(article: article)
        }

        if !article.officialContacts.isEmpty {
            GuidanceOfficialContactsView(contacts: article.officialContacts)
        }
    }
}

/// `.help` / `.helpHealth` 冒頭の淡い下地カード（Figma `2720:5403` / `2720:5427`）。
private struct GuidanceHighlightCardView: View {
    let highlight: GuidanceHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Image(systemName: highlight.systemImageName)
                .font(.title2)
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            Text(highlight.title)
                .font(.title2.bold())

            Text(highlight.bodyText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NexusTheme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusPanel(surfaceColor, cornerRadius: NexusTheme.cardCornerRadius)
        .accessibilityElement(children: .combine)
    }

    private var surfaceColor: Color {
        switch highlight.tone {
        case .informational:
            return NexusTheme.tintSurface
        case .caution:
            return NexusTheme.cautionSurface
        }
    }

    private var accentColor: Color {
        switch highlight.tone {
        case .informational:
            return .accentColor
        case .caution:
            return NexusTheme.cautionAccent
        }
    }
}

/// 確認済みの公式連絡先のみ。利用者の操作から開く（#86 G06）。
private struct GuidanceOfficialContactsView: View {
    @Environment(\.openURL) private var openURL

    let contacts: [GuidanceOfficialContact]

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Text("公式のお問い合わせ")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(contacts) { contact in
                Button {
                    openURL(contact.url)
                } label: {
                    Label(contact.label, systemImage: contact.kind == .phone ? "phone" : "safari")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}
