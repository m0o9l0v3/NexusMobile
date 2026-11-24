#if DEBUG
import SwiftUI

/// Preview／シミュレーター比較専用の検討用データ。
///
/// 本文は Figma 上の「内容確認中」の仮原稿をそのまま持つ。**正式な案内原稿ではない。**
/// 受付（本館1階）の canonical ID は未確定なので、関連地点は ID 付きでは作らず
/// `unresolvedRelatedPlaceNote` に落とす（Implementation Notes `2730:2942` / #86）。
enum GuidancePreviewFixtures {
    // MARK: - 記事ID

    static let receptionID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_RECEPTION")
    static let accessID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_ACCESS")
    static let facilityID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_FACILITY")
    static let faqID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_FAQ")
    static let lostID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_LOST")
    static let healthID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_HEALTH")
    static let parkingID = GuidanceArticleID(rawValue: "PREVIEW_GUIDE_PARKING")

    /// 受付（本館1階）の canonical ID が未確定であることの説明。
    static let unresolvedReceptionNote =
        "受付（本館1階）の地点IDが未確定のため、この案内からは場所・経路を開けません。地点IDの確定後に接続します。"

    static let savedMetadata = NexusSavedMetadata(
        title: "保存版の案内を表示しています",
        detail: "最新情報は確認できていません。"
    )

    // MARK: - 案内トップ

    private static let previewArticleIDs: [GuidanceMenuTopic: GuidanceArticleID] = [
        .health: healthID, .help: lostID, .reception: receptionID, .access: accessID,
        .facility: facilityID, .faq: faqID, .about: GuidanceMenuTopic.about.defaultArticleID
    ]

    static let topSnapshot = GuidanceTopSnapshot(
        sections: GuidanceMenuSection.Kind.allCases.map { kind in
            GuidanceMenuSection(kind: kind, items: kind.topics.map { topic in
                GuidanceMenuItem(topic: topic, articleID: previewArticleIDs[topic])
            })
        }
    )

    // MARK: - 記事

    static let receptionArticle = GuidanceArticle(
        id: receptionID,
        kind: .standard,
        navigationTitle: "受付案内",
        title: "受付案内",
        subtitle: "来場後の受付についてご案内します。",
        sections: [
            GuidanceSection(id: "place", heading: "受付場所", paragraphs: ["本館1階"]),
            GuidanceSection(
                id: "flow",
                heading: "受付の流れ",
                paragraphs: ["内容確認中。正式な受付手順に差し替えます。"]
            ),
            GuidanceSection(
                id: "notes",
                heading: "確認事項",
                paragraphs: ["必要な持ち物・受付時間は内容確認中です。"]
            ),
        ],
        unresolvedRelatedPlaceNote: unresolvedReceptionNote,
        confirmation: GuidanceCalendarDate(isoDate: "2026-11-13").map { date in
            GuidanceConfirmation(source: "プレビュー用の出典", confirmedOn: date, confirmer: "プレビュー用の確認者")
        }
    )

    static let lostArticle = GuidanceArticle(
        id: lostID,
        kind: .help,
        navigationTitle: "道に迷った",
        title: "道に迷った",
        highlight: GuidanceHighlight(
            tone: .informational,
            systemImageName: "figure.walk",
            title: "道に迷った",
            bodyText: "まず立ち止まり、近くの建物や案内表示を確認しましょう。"
        ),
        sections: [
            GuidanceSection(
                id: "step1",
                heading: "1 周囲を確認する",
                paragraphs: ["Mapを開き、現在地や周辺の建物を確認できます。"]
            ),
            GuidanceSection(
                id: "step2",
                heading: "2 スタッフへ相談する",
                paragraphs: ["近くのスタッフに、向かいたい場所を伝えてください。"]
            ),
        ],
        unresolvedRelatedPlaceNote: unresolvedReceptionNote
    )

    static let healthArticle = GuidanceArticle(
        id: healthID,
        kind: .helpHealth,
        navigationTitle: "気分が悪くなったら",
        title: "気分が悪くなったら",
        highlight: GuidanceHighlight(
            tone: .caution,
            systemImageName: "info.circle",
            title: "気分が悪くなったら",
            bodyText: "無理に移動せず、近くのスタッフへ体調が悪いことを伝えてください。"
        ),
        sections: [
            GuidanceSection(
                id: "step1",
                heading: "1 スタッフに知らせる",
                paragraphs: ["近くの人やスタッフに声をかけてください。"]
            ),
            GuidanceSection(
                id: "step2",
                heading: "2 その場で案内を待つ",
                paragraphs: ["移動が難しい場合は、その場でスタッフに相談してください。"]
            ),
        ],
        unresolvedRelatedPlaceNote: unresolvedReceptionNote
    )

    static let accessArticle = GuidanceArticle(
        id: accessID,
        kind: .access,
        navigationTitle: "アクセス",
        title: "アクセス",
        unresolvedRelatedPlaceNote: unresolvedReceptionNote,
        accessSegments: [
            GuidanceAccessSegment(
                mode: .train,
                sections: [
                    GuidanceSection(
                        id: "train-route",
                        heading: "電車でお越しの方",
                        paragraphs: ["最寄り駅・乗り換え・所要時間は内容確認中です。正式なアクセス案内に差し替えます。"]
                    ),
                    GuidanceSection(
                        id: "train-arrival",
                        heading: "到着後のご案内",
                        paragraphs: ["受付は本館1階です。受付の詳細は「受付案内」で確認できます。"]
                    ),
                ]
            ),
            GuidanceAccessSegment(
                mode: .bus,
                sections: [
                    GuidanceSection(
                        id: "bus-route",
                        heading: "バスでお越しの方",
                        paragraphs: ["路線・停留所・所要時間は内容確認中です。正式なアクセス案内に差し替えます。"]
                    )
                ]
            ),
            GuidanceAccessSegment(
                mode: .car,
                sections: [
                    GuidanceSection(
                        id: "car-route",
                        heading: "自動車でお越しの方",
                        paragraphs: ["経路・駐車場の受け入れ可否は内容確認中です。正式なアクセス案内に差し替えます。"]
                    )
                ]
            ),
        ]
    )

    static let faqArticle = GuidanceArticle(
        id: faqID,
        kind: .faq,
        navigationTitle: "よくある質問",
        title: "よくある質問",
        subtitle: "質問を押すと回答が開きます。",
        faqItems: [
            GuidanceFAQItem(
                id: "faq-reception",
                category: "来場・受付",
                question: "受付はどこですか？",
                answerParagraphs: ["本館1階です。詳細は「受付案内」で確認できます。"]
            ),
            GuidanceFAQItem(
                id: "faq-access",
                category: "来場・受付",
                question: "学校までのアクセスを確認したい",
                answerParagraphs: ["「アクセス」で電車・バス・自動車それぞれの案内を確認できます。内容は確認中です。"]
            ),
            GuidanceFAQItem(
                id: "faq-lost",
                category: "困ったとき",
                question: "道に迷った場合は？",
                answerParagraphs: ["「困ったとき」の『道に迷った』をご覧ください。"]
            ),
            GuidanceFAQItem(
                id: "faq-health",
                category: "困ったとき",
                question: "体調が悪くなった場合は？",
                answerParagraphs: ["無理に移動せず、近くのスタッフへお伝えください。"]
            ),
        ]
    )

    /// 関連地点の canonical ID が確定している場合の確認用。
    /// 代表 canonical ID `mb_2f_cl_001` を使い、記事 → 関連地点 → 経路の受け渡しを確認する。
    static let facilityArticle = GuidanceArticle(
        id: facilityID,
        kind: .standard,
        navigationTitle: "施設利用",
        title: "施設利用",
        subtitle: "構内の施設のご利用についてご案内します。",
        sections: [
            GuidanceSection(
                id: "facility-notes",
                heading: "ご利用にあたって",
                paragraphs: ["利用可能な施設と時間帯は内容確認中です。"]
            )
        ],
        relatedPlaces: [
            GuidanceRelatedPlace(
                canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
                displayName: "2A教室",
                supplementaryText: "教室棟・2F"
            )
        ]
    )

    static let articlesByID: [GuidanceArticleID: GuidanceArticle] = [
        receptionID: receptionArticle,
        lostID: lostArticle,
        healthID: healthArticle,
        accessID: accessArticle,
        faqID: faqArticle,
        facilityID: facilityArticle,
    ]
}

extension GuidanceClient {
    static func preview(
        top: GuidanceTopFetchResult = .fresh(GuidancePreviewFixtures.topSnapshot),
        articles: [GuidanceArticleID: GuidanceArticle] = GuidancePreviewFixtures.articlesByID
    ) -> GuidanceClient {
        GuidanceClient(
            fetchTop: { top },
            fetchArticle: { articleID in
                if let article = articles[articleID] {
                    return .fresh(article)
                }
                return BundledGuidanceCatalog(articles: []).articleFetchResult(for: articleID)
            },
            failureMessage: GuidanceClient.unconfigured.failureMessage
        )
    }
}

@MainActor
private func previewGuidanceStore(
    topState: GuidanceTopViewState = .loaded(GuidancePreviewFixtures.topSnapshot),
    articleStates: [GuidanceArticleID: GuidanceArticleViewState] = [:]
) -> GuidanceStore {
    GuidanceStore(
        client: .preview(),
        initialTopState: topState,
        initialArticleStates: articleStates
    )
}

@MainActor
private func previewArticle(
    _ article: GuidanceArticle,
    savedMetadata: NexusSavedMetadata? = nil
) -> some View {
    let state: GuidanceArticleViewState = savedMetadata.map {
        .saved(article, $0)
    } ?? .loaded(article)

    return NavigationStack {
        GuidanceArticleView(
            articleID: article.id,
            store: previewGuidanceStore(articleStates: [article.id: state])
        )
    }
}

#Preview("案内トップ 393×852") {
    NavigationStack {
        GuidanceTopView(
            store: previewGuidanceStore(),
            routeStore: RouteRequestStore(handler: .unconfigured)
        )
    }
}

#Preview("案内トップ・保存版") {
    NavigationStack {
        GuidanceTopView(
            store: previewGuidanceStore(
                topState: .saved(GuidancePreviewFixtures.topSnapshot, GuidancePreviewFixtures.savedMetadata)
            ),
            routeStore: RouteRequestStore(handler: .unconfigured)
        )
    }
}

#Preview("案内トップ・通信失敗") {
    NavigationStack {
        GuidanceTopView(
            store: previewGuidanceStore(topState: .failed(GuidanceClient.unconfigured.failureMessage)),
            routeStore: RouteRequestStore(handler: .unconfigured)
        )
    }
}

#Preview("詳細・受付案内 Standard") {
    previewArticle(GuidancePreviewFixtures.receptionArticle)
}

#Preview("詳細・道に迷った Help") {
    previewArticle(GuidancePreviewFixtures.lostArticle)
}

#Preview("詳細・体調が悪い Help Health") {
    previewArticle(GuidancePreviewFixtures.healthArticle)
}

#Preview("詳細・アクセス Access") {
    previewArticle(GuidancePreviewFixtures.accessArticle)
}

#Preview("詳細・よくある質問 FAQ") {
    previewArticle(GuidancePreviewFixtures.faqArticle)
}

#Preview("詳細・関連地点あり（保存版）") {
    previewArticle(
        GuidancePreviewFixtures.facilityArticle,
        savedMetadata: GuidancePreviewFixtures.savedMetadata
    )
}

#Preview("詳細・原稿未提供") {
    NavigationStack {
        GuidanceArticleView(
            articleID: GuidancePreviewFixtures.parkingID,
            store: previewGuidanceStore(
                articleStates: [
                    GuidancePreviewFixtures.parkingID: .notProvided(GuidancePreviewFixtures.parkingID)
                ]
            )
        )
    }
}

#Preview("案内トップ・ダーク") {
    NavigationStack {
        GuidanceTopView(
            store: previewGuidanceStore(),
            routeStore: RouteRequestStore(handler: .unconfigured)
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("案内トップ・AXXXL") {
    NavigationStack {
        GuidanceTopView(
            store: previewGuidanceStore(),
            routeStore: RouteRequestStore(handler: .unconfigured)
        )
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
