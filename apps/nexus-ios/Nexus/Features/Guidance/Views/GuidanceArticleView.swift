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
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, NexusTheme.spacing20)
            .padding(.top, NexusTheme.spacing16)
            .padding(.bottom, 36)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await store.loadArticleIfNeeded(articleID)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.articleState(for: articleID) {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
                .accessibilityLabel("案内を読み込み中")

        case .loaded(let article), .saved(let article, _):
            GuidanceArticleBodyView(article: article)

        case .notProvided:
            NexusStatusView(
                message: NexusStateMessage(
                    title: "この案内は準備中です",
                    detail: "内容の確認が済み次第、アプリの更新で掲載します。",
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

/// 記事の見出しと、種類ごとの本文（Figma `2825:2416` / `2825:2657`）。
private struct GuidanceArticleBodyView: View {
    let article: GuidanceArticle

    var body: some View {
        Text(article.title)
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        if let subtitle = article.subtitle {
            Text(subtitle)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }

        if let highlight = article.highlight {
            GuidanceArticleSectionView(section: GuidanceSection(
                id: "introduction",
                heading: highlight.title == article.title ? nil : highlight.title,
                paragraphs: [highlight.bodyText]
            ))
        }

        switch article.kind {
        case .standard, .help, .helpHealth:
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

/// 確認済みの公式連絡先のみ。利用者の操作から開く（#86 G06）。
private struct GuidanceOfficialContactsView: View {
    @Environment(\.openURL) private var openURL

    let contacts: [GuidanceOfficialContact]

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            Text("公式サイト・お問い合わせ")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            ForEach(contacts) { contact in
                Button {
                    openURL(contact.url)
                } label: {
                    Label(contact.label, systemImage: contact.kind == .phone ? "phone" : "safari")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}
