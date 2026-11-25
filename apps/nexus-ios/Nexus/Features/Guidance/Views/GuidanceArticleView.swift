import SwiftUI

enum GuidanceArticleAnchor: Hashable {
    case relatedPlaces
    case officialContacts
}

/// 案内詳細。Figma の5画面はレイアウトを `GuidanceArticleKind` で選ぶ。
/// 記事IDによる分岐は本番コードに置かない。
///
/// - `.standard`   `2723:2622` GuidanceDetail / Standard
/// - `.help`       `2723:2675` GuidanceDetail / Help
/// - `.helpHealth` `2723:2824` GuidanceDetail / Help Health
/// - `.access`     `2723:2729` GuidanceDetail / Access
/// - `.faq`        `2723:2793` GuidanceDetail / FAQ
struct GuidanceArticleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let articleID: GuidanceArticleID
    let store: GuidanceStore

    @State private var isRelatedPlacesVisible = false
    @State private var isOfficialContactsVisible = false
    @State private var accessHasRelatedPlaces = false
    @State private var jumpFeedbackCount = 0

    private var loadedArticle: GuidanceArticle? {
        switch store.articleState(for: articleID) {
        case .loaded(let article), .saved(let article, _):
            return article
        case .idle, .loading, .notProvided, .failed:
            return nil
        }
    }

    private func hasRelatedPlaces(for article: GuidanceArticle) -> Bool {
        article.kind == .access ? accessHasRelatedPlaces : !article.relatedPlaces.isEmpty
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            Group {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        content
                    }
                    .padding(.horizontal, NexusTheme.spacing20)
                    .padding(.top, NexusTheme.spacing16)
                    .padding(.bottom, 36)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                quickJumpInset(scrollProxy: scrollProxy)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await store.loadArticleIfNeeded(articleID)
        }
        .onChange(of: articleID) { _, _ in
            isRelatedPlacesVisible = false
            isOfficialContactsVisible = false
            accessHasRelatedPlaces = false
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
            GuidanceArticleBodyView(
                article: article,
                onRelatedPlacesVisibilityChange: { isRelatedPlacesVisible = $0 },
                onOfficialContactsVisibilityChange: { isOfficialContactsVisible = $0 },
                onAccessHasRelatedPlacesChange: { accessHasRelatedPlaces = $0 }
            )

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

    @ViewBuilder
    private func quickJumpInset(scrollProxy: ScrollViewProxy) -> some View {
        if let article = loadedArticle {
            let showPlaces = hasRelatedPlaces(for: article) && !isRelatedPlacesVisible
            let showContacts = !article.officialContacts.isEmpty && !isOfficialContactsVisible

            if showPlaces || showContacts {
                quickJumpBar(
                    article: article,
                    showPlaces: showPlaces,
                    showContacts: showContacts,
                    scrollProxy: scrollProxy
                )
                .padding(.horizontal, NexusTheme.spacing16)
                .padding(.top, NexusTheme.spacing8)
                .padding(.bottom, NexusTheme.spacing12)
                .sensoryFeedback(.impact(weight: .light), trigger: jumpFeedbackCount)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showPlaces)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showContacts)
            }
        }
    }

    @ViewBuilder
    private func quickJumpBar(
        article: GuidanceArticle,
        showPlaces: Bool,
        showContacts: Bool,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        if showPlaces && showContacts && !dynamicTypeSize.isAccessibilitySize {
            let contactsLabel = contactsCompactLabel(for: article.officialContacts)
            let contactsIcon = article.officialContacts.contains { $0.kind == .phone } ? "phone.fill" : "safari"

            HStack(spacing: NexusTheme.spacing8) {
                Button {
                    scrollTo(.relatedPlaces, using: scrollProxy)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .accessibilityHidden(true)
                        Text("関連する場所")
                            .lineLimit(1)
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, NexusTheme.spacing12)
                    .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                    .background(NexusTheme.tintSurface, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.nexusPressableCapsule)
                .accessibilityLabel("関連する場所へ移動")
                .accessibilityHint("画面下の地図・経路カードへスクロールします")

                Button {
                    scrollTo(.officialContacts, using: scrollProxy)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: contactsIcon)
                            .accessibilityHidden(true)
                        Text(contactsLabel)
                            .lineLimit(1)
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NexusTheme.onAccent)
                    .padding(.horizontal, NexusTheme.spacing12)
                    .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                    .background(Color.accentColor, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.nexusPressableCapsule)
                .accessibilityLabel("\(contactsLabel)へ移動")
                .accessibilityHint("画面下の連絡先・公式リンクへスクロールします")
            }
            .padding(6)
            .nexusFloatingSurface(cornerRadius: 28)
        } else {
            let targetAnchor: GuidanceArticleAnchor = showPlaces ? .relatedPlaces : .officialContacts
            let iconName = targetAnchor == .relatedPlaces
                ? "mappin.and.ellipse"
                : (article.officialContacts.contains { $0.kind == .phone } ? "phone.fill" : "safari")
            let labelText = targetAnchor == .relatedPlaces
                ? "関連する場所（地図・経路）を見る"
                : contactsSingleBarLabel(for: article.officialContacts)
            let hintText = targetAnchor == .relatedPlaces
                ? "画面下の地図・経路カードへスクロールします"
                : "画面下の連絡先・公式リンクへスクロールします"

            Button {
                scrollTo(targetAnchor, using: scrollProxy)
            } label: {
                HStack(spacing: NexusTheme.spacing12) {
                    Image(systemName: iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text(labelText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, NexusTheme.spacing16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .nexusFloatingSurface(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 24 : 28)
            }
            .buttonStyle(.nexusPressable(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 24 : 28))
            .accessibilityLabel("\(labelText)へ移動")
            .accessibilityHint(hintText)
        }
    }

    private func contactsCompactLabel(for contacts: [GuidanceOfficialContact]) -> String {
        let hasPhone = contacts.contains { $0.kind == .phone }
        let hasWeb = contacts.contains { $0.kind == .web }
        if hasPhone && hasWeb { return "電話・公式" }
        if hasPhone { return "お問い合わせ" }
        if contacts.count > 1 { return "公式リンク（\(contacts.count)件）" }
        return "公式サイト"
    }

    private func contactsSingleBarLabel(for contacts: [GuidanceOfficialContact]) -> String {
        let hasPhone = contacts.contains { $0.kind == .phone }
        let hasWeb = contacts.contains { $0.kind == .web }
        if hasPhone && hasWeb { return "電話・公式サイトを見る" }
        if hasPhone { return "電話お問い合わせを見る" }
        if contacts.count > 1 { return "公式リンクを見る（\(contacts.count)件）" }
        return "公式サイトを見る"
    }

    private func scrollTo(_ anchor: GuidanceArticleAnchor, using proxy: ScrollViewProxy) {
        jumpFeedbackCount += 1
        if reduceMotion {
            proxy.scrollTo(anchor, anchor: .top)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
    }
}

/// 記事の見出しと、種類ごとの本文（Figma `2825:2416` / `2825:2657`）。
private struct GuidanceArticleBodyView: View {
    let article: GuidanceArticle
    let onRelatedPlacesVisibilityChange: (Bool) -> Void
    let onOfficialContactsVisibilityChange: (Bool) -> Void
    let onAccessHasRelatedPlacesChange: (Bool) -> Void

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

            if !article.relatedPlaces.isEmpty {
                GuidanceRelatedPlaceView(
                    places: article.relatedPlaces,
                    unresolvedNote: article.unresolvedRelatedPlaceNote
                )
                .id(GuidanceArticleAnchor.relatedPlaces)
                .onScrollVisibilityChange(threshold: 0.15, onRelatedPlacesVisibilityChange)
            } else if article.unresolvedRelatedPlaceNote != nil {
                GuidanceRelatedPlaceView(
                    places: article.relatedPlaces,
                    unresolvedNote: article.unresolvedRelatedPlaceNote
                )
            }

        case .access:
            GuidanceAccessArticleView(
                article: article,
                onRelatedPlacesVisibilityChange: onRelatedPlacesVisibilityChange,
                onHasRelatedPlacesChange: onAccessHasRelatedPlacesChange
            )

        case .faq:
            GuidanceFAQArticleView(article: article)
        }

        if !article.officialContacts.isEmpty {
            GuidanceOfficialContactsView(contacts: article.officialContacts)
                .id(GuidanceArticleAnchor.officialContacts)
                .onScrollVisibilityChange(threshold: 0.15, onOfficialContactsVisibilityChange)
        }
    }
}

/// 確認済みの公式連絡先のみ。利用者の操作から開く（#86 G06）。
private struct GuidanceOfficialContactsView: View {
    @Environment(\.openURL) private var openURL

    let contacts: [GuidanceOfficialContact]

    private var headerIconName: String {
        contacts.contains { $0.kind == .phone } ? "phone.bubble" : "globe"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            HStack(spacing: NexusTheme.spacing8) {
                Image(systemName: headerIconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("公式サイト・お問い合わせ")
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, NexusTheme.spacing16)
                            .accessibilityHidden(true)
                    }

                    Button {
                        openURL(contact.url)
                    } label: {
                        HStack(spacing: NexusTheme.spacing12) {
                            Circle()
                                .fill(NexusTheme.tintSurface)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: contact.kind == .phone ? "phone.fill" : "safari")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(contact.label)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(contact.kind == .phone ? "電話をかける" : "公式サイトを開く（外部）")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: contact.kind == .phone ? "phone.arrow.up.right" : "arrow.up.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, NexusTheme.spacing16)
                        .padding(.vertical, 14)
                        .nexusTappableRow(minHeight: 60)
                    }
                    .buttonStyle(.nexusPressableRow)
                    .accessibilityLabel(contact.label)
                    .accessibilityHint(contact.kind == .phone ? "電話アプリを開きます" : "外部サイトをブラウザで開きます")
                }
            }
            .nexusCard(cornerRadius: NexusTheme.cardCornerRadius, elevation: .level2)
        }
    }
}
