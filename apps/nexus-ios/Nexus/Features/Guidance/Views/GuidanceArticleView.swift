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
    @Namespace private var quickJumpNamespace

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
        switch article.kind {
        case .standard, .help, .helpHealth:
            return !article.relatedPlaces.isEmpty
        case .access:
            return accessHasRelatedPlaces
        case .faq:
            return false
        }
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
        // タブバーは push した記事側で隠す。NavigationStack の外から path に合わせて切り替えると、
        // 戻る遷移の途中でタブバーの表示が変わり、遷移が止まって操作できなくなることがある。
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
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: showPlaces)
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: showContacts)
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
            ViewThatFits(in: .horizontal) {
                dualQuickJumpRow(article: article, scrollProxy: scrollProxy)
                singleQuickJumpButton(
                    article: article,
                    targetAnchor: .relatedPlaces,
                    scrollProxy: scrollProxy
                )
            }
        } else {
            let targetAnchor: GuidanceArticleAnchor = showPlaces ? .relatedPlaces : .officialContacts
            singleQuickJumpButton(
                article: article,
                targetAnchor: targetAnchor,
                scrollProxy: scrollProxy
            )
        }
    }

    private func dualQuickJumpRow(
        article: GuidanceArticle,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let contactsLabel = contactsCompactLabel(for: article.officialContacts)
        let contactsA11yLabel = contactsCompactAccessibilityLabel(for: article.officialContacts)
        let contactsIcon = article.officialContacts.contains { $0.kind == .phone } ? "phone.fill" : "safari"

        return NexusGlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    scrollTo(.relatedPlaces, using: scrollProxy)
                } label: {
                    HStack(spacing: 8) {
                        quickJumpIconBadge(systemImage: "mappin.and.ellipse", prominent: false, size: 28)

                        Text("関連する場所")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 2)

                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.nexusFloatingCapsule)
                .nexusGlassID("places", in: quickJumpNamespace)
                .accessibilityLabel("関連する場所へ移動")
                .accessibilityHint("画面下の地図・経路カードへスクロールします")

                Button {
                    scrollTo(.officialContacts, using: scrollProxy)
                } label: {
                    HStack(spacing: 8) {
                        quickJumpIconBadge(systemImage: contactsIcon, prominent: true, size: 28)

                        Text(contactsLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 2)

                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.nexusFloatingCapsule)
                .nexusGlassID("contacts", in: quickJumpNamespace)
                .accessibilityLabel("\(contactsA11yLabel)へ移動")
                .accessibilityHint("画面下の連絡先・公式リンクへスクロールします")
            }
        }
    }

    @ViewBuilder
    private func singleQuickJumpButton(
        article: GuidanceArticle,
        targetAnchor: GuidanceArticleAnchor,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let isPlaces = targetAnchor == .relatedPlaces
        let iconName = isPlaces
            ? "mappin.and.ellipse"
            : (article.officialContacts.contains { $0.kind == .phone } ? "phone.fill" : "safari")
        let labelText = isPlaces
            ? "関連する場所（地図・経路）を見る"
            : contactsSingleBarLabel(for: article.officialContacts)
        let hintText = isPlaces
            ? "画面下の地図・経路カードへスクロールします"
            : "画面下の連絡先・公式リンクへスクロールします"
        let glassID = isPlaces ? "places" : "contacts"

        NexusGlassContainer(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                Button {
                    scrollTo(targetAnchor, using: scrollProxy)
                } label: {
                    singleQuickJumpLabel(
                        iconName: iconName,
                        prominentBadge: !isPlaces,
                        labelText: labelText,
                        isAccessibilitySize: true
                    )
                }
                .buttonStyle(.nexusFloatingRoundedRect(cornerRadius: 24))
                .nexusGlassID(glassID, in: quickJumpNamespace)
                .accessibilityLabel("\(labelText)へ移動")
                .accessibilityHint(hintText)
            } else {
                Button {
                    scrollTo(targetAnchor, using: scrollProxy)
                } label: {
                    singleQuickJumpLabel(
                        iconName: iconName,
                        prominentBadge: !isPlaces,
                        labelText: labelText,
                        isAccessibilitySize: false
                    )
                }
                .buttonStyle(.nexusFloatingCapsule)
                .nexusGlassID(glassID, in: quickJumpNamespace)
                .accessibilityLabel("\(labelText)へ移動")
                .accessibilityHint(hintText)
            }
        }
    }

    private func singleQuickJumpLabel(
        iconName: String,
        prominentBadge: Bool,
        labelText: String,
        isAccessibilitySize: Bool
    ) -> some View {
        HStack(alignment: isAccessibilitySize ? .top : .center, spacing: NexusTheme.spacing12) {
            quickJumpIconBadge(systemImage: iconName, prominent: prominentBadge, size: 32)

            Text(labelText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Circle()
                .fill(NexusTheme.tintSurface)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, isAccessibilitySize ? 12 : 9)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
    }

    private func quickJumpIconBadge(systemImage: String, prominent: Bool, size: CGFloat) -> some View {
        Circle()
            .fill(prominent ? Color.accentColor : NexusTheme.tintSurface)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(prominent ? NexusTheme.onAccent : Color.accentColor)
            }
            .accessibilityHidden(true)
    }

    private func contactsCompactLabel(for contacts: [GuidanceOfficialContact]) -> String {
        let hasPhone = contacts.contains { $0.kind == .phone }
        let hasWeb = contacts.contains { $0.kind == .web }
        if hasPhone && hasWeb { return "電話・公式" }
        if hasPhone { return "お問い合わせ" }
        if contacts.count > 1 { return "公式リンク" }
        return "公式サイト"
    }

    private func contactsCompactAccessibilityLabel(for contacts: [GuidanceOfficialContact]) -> String {
        if !contacts.contains(where: { $0.kind == .phone }), contacts.count > 1 {
            return "公式リンク（\(contacts.count)件）"
        }
        return contactsCompactLabel(for: contacts)
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
            GuidanceHighlightCalloutView(
                highlight: highlight,
                showsHeading: highlight.title != article.title
            )
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

/// `.help` / `.helpHealth` 冒頭の重要行動コールアウト。
private struct GuidanceHighlightCalloutView: View {
    let highlight: GuidanceHighlight
    let showsHeading: Bool

    private var isCaution: Bool { highlight.tone == .caution }

    private var accentColor: Color {
        isCaution ? NexusTheme.cautionAccent : Color.accentColor
    }

    private var tintOverlay: Color {
        isCaution ? NexusTheme.cautionSurface : NexusTheme.tintSurface
    }

    private var borderColor: Color {
        isCaution ? NexusTheme.cautionAccent : Color.accentColor.opacity(0.28)
    }

    var body: some View {
        HStack(alignment: .top, spacing: NexusTheme.spacing12) {
            Circle()
                .fill(NexusTheme.cardSurface)
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: highlight.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
                if showsHeading {
                    Text(highlight.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isCaution ? NexusTheme.cautionAccent : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }

                Text(highlight.bodyText)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(NexusTheme.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                NexusTheme.cardSurface
                tintOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .nexusElevation(.level1)
    }
}

/// 確認済みの公式連絡先のみ。利用者の操作から開く（#86 G06）。
private struct GuidanceOfficialContactsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let contacts: [GuidanceOfficialContact]
    @State private var tapFeedbackCount = 0

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
                        tapFeedbackCount += 1
                        openURL(contact.url)
                    } label: {
                        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: NexusTheme.spacing12) {
                            Circle()
                                .fill(contact.kind == .phone ? Color.accentColor : NexusTheme.tintSurface)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: contact.kind == .phone ? "phone.fill" : "safari")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(contact.kind == .phone ? NexusTheme.onAccent : Color.accentColor)
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
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Circle()
                                .fill(NexusTheme.tintSurface)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: contact.kind == .phone ? "phone.arrow.up.right" : "arrow.up.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, NexusTheme.spacing16)
                        .padding(.vertical, 14)
                        .nexusTappableRow(minHeight: 62)
                    }
                    .buttonStyle(.nexusPressableRow)
                    .accessibilityLabel(contact.label)
                    .accessibilityHint(contact.kind == .phone ? "電話アプリを開きます" : "外部サイトをブラウザで開きます")
                }
            }
            .nexusCard(cornerRadius: NexusTheme.primaryCardCornerRadius, elevation: .level2)
            .sensoryFeedback(.impact(weight: .light), trigger: tapFeedbackCount)
        }
    }
}
