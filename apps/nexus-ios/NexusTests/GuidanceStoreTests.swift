import XCTest
@testable import Nexus

@MainActor
final class GuidanceStoreTests: XCTestCase {

    private let receptionID = GuidanceArticleID(rawValue: "reception")
    private let accessID = GuidanceArticleID(rawValue: "access")


    // MARK: - 更新状態の文言（Figma 2720:5360 / 5362 / 5364）

    func testNormalUpdateStatusMessage() {
        XCTAssertEqual(GuidanceUpdateStatus.normal.message, "更新状況：内容確認中")
    }

    func testOfflineUpdateStatusMessage() {
        XCTAssertEqual(
            GuidanceUpdateStatus.offline.message,
            "オフライン保存版・更新状況は確認できません"
        )
    }

    func testUnavailableUpdateStatusMessage() {
        XCTAssertEqual(
            GuidanceUpdateStatus.unavailable.message,
            "最新情報を確認できません・保存済みの内容を表示"
        )
    }

    /// 更新状態はペイロード由来。到達性から推測しない。
    func testUpdateStatusIsTakenFromPayloadNotInferred() async {
        let store = GuidanceStore(
            client: .stub(article: { id in
                .fresh(makeTestArticle(id, updateStatus: .offline))
            })
        )

        await store.loadArticleIfNeeded(receptionID)

        guard case .loaded(let loaded) = store.articleState(for: receptionID) else {
            return XCTFail("読み込み済みにならなかった")
        }
        XCTAssertEqual(loaded.updateStatus, .offline)
    }

    // MARK: - トップ

    func testTopSnapshotLoadsWithSections() async {
        let snapshot = GuidanceTopSnapshot(
            todayCard: GuidanceTodayCard(title: "本日のご案内", primaryActionTitle: "当日の流れ"),
            frequentItems: [
                GuidanceMenuItem(id: receptionID, title: "受付案内", systemImageName: "person.fill")
            ],
            troubleItems: [
                GuidanceMenuItem(
                    id: GuidanceArticleID(rawValue: "lost"),
                    title: "道に迷った",
                    systemImageName: "figure.walk"
                )
            ],
            sections: [
                GuidanceMenuSection(
                    id: "arrival",
                    heading: "来場案内",
                    items: [
                        GuidanceMenuItem(id: accessID, title: "アクセス", systemImageName: "location")
                    ]
                )
            ],
            updateStatus: .normal
        )
        let store = GuidanceStore(
            client: .stub(top: { .fresh(snapshot) }, article: { .notProvided($0) })
        )

        await store.loadTopIfNeeded()

        guard case .loaded(let loaded) = store.topState else {
            return XCTFail("読み込み済みにならなかった: \(store.topState)")
        }
        XCTAssertNotNil(loaded.todayCard)
        XCTAssertEqual(loaded.frequentItems.count, 1)
        XCTAssertEqual(loaded.troubleItems.count, 1)
        XCTAssertEqual(loaded.sections.first?.heading, "来場案内")
    }

    func testTopFailureUsesConfiguredFailureMessage() async {
        let store = GuidanceStore(
            client: .stub(top: { throw TestStubError.simulated }, article: { .notProvided($0) })
        )

        await store.loadTopIfNeeded()

        guard case .failed(let message) = store.topState else {
            return XCTFail("失敗状態にならなかった: \(store.topState)")
        }
        XCTAssertEqual(message, .testFailure)
    }

    // MARK: - 記事

    func testArticleStatesAreKeyedByIdentifierAndIndependent() async {
        let store = GuidanceStore(client: .stub(article: { id in .fresh(makeTestArticle(id)) }))

        await store.loadArticleIfNeeded(receptionID)

        guard case .loaded = store.articleState(for: receptionID) else {
            return XCTFail("受付案内が読み込まれなかった")
        }
        XCTAssertEqual(store.articleState(for: accessID), .idle)
    }

    /// 未提供の記事が他の記事へフォールバックしない。
    func testNotProvidedArticleDoesNotFallBackToAnotherArticle() async {
        // `@Sendable` クロージャから `@MainActor` のプロパティを読まないようローカルへ退避する。
        let provided = receptionID
        let store = GuidanceStore(
            client: .stub(article: { id in
                id == provided ? .fresh(makeTestArticle(id)) : .notProvided(id)
            })
        )

        await store.loadArticleIfNeeded(receptionID)
        await store.loadArticleIfNeeded(accessID)

        guard case .notProvided(let requestedID) = store.articleState(for: accessID) else {
            return XCTFail("未提供状態にならなかった: \(store.articleState(for: accessID))")
        }
        XCTAssertEqual(requestedID, accessID)
        if case .loaded = store.articleState(for: accessID) {
            XCTFail("未提供の記事に内容が入った")
        }
    }

    func testArticleFailureUsesConfiguredFailureMessage() async {
        let store = GuidanceStore(client: .stub(article: { _ in throw TestStubError.simulated }))

        await store.loadArticleIfNeeded(receptionID)

        guard case .failed(let message) = store.articleState(for: receptionID) else {
            return XCTFail("失敗状態にならなかった")
        }
        XCTAssertEqual(message, .testFailure)
    }

    func testSavedArticleCarriesMetadata() async {
        let metadata = NexusSavedMetadata(title: "保存版", detail: nil)
        let store = GuidanceStore(
            client: .stub(article: { id in .saved(makeTestArticle(id), metadata) })
        )

        await store.loadArticleIfNeeded(receptionID)

        guard case .saved(_, let received) = store.articleState(for: receptionID) else {
            return XCTFail("保存版状態にならなかった")
        }
        XCTAssertEqual(received, metadata)
    }

    func testAccessArticleExposesThreeModesInFixedOrder() async {
        let segments = GuidanceAccessMode.allCases.map {
            GuidanceAccessSegment(mode: $0, sections: [])
        }
        let store = GuidanceStore(
            client: .stub(article: { id in
                .fresh(makeTestArticle(id, kind: .access, accessSegments: segments))
            })
        )

        await store.loadArticleIfNeeded(accessID)

        guard case .loaded(let loaded) = store.articleState(for: accessID) else {
            return XCTFail("読み込み済みにならなかった")
        }
        XCTAssertEqual(loaded.accessSegments.map(\.mode), [.train, .bus, .car])
        XCTAssertEqual(
            loaded.accessSegments.map(\.mode.displayName),
            ["電車", "バス", "自動車"]
        )
    }

    func testFAQItemsKeepSourceOrderAndUniqueIdentifiers() async {
        let items = [
            GuidanceFAQItem(id: "q3", question: "3", answerParagraphs: []),
            GuidanceFAQItem(id: "q1", question: "1", answerParagraphs: []),
            GuidanceFAQItem(id: "q2", question: "2", answerParagraphs: []),
        ]
        let faqID = GuidanceArticleID(rawValue: "faq")
        let store = GuidanceStore(
            client: .stub(article: { id in .fresh(makeTestArticle(id, kind: .faq, faqItems: items)) })
        )

        await store.loadArticleIfNeeded(faqID)

        guard case .loaded(let loaded) = store.articleState(for: faqID) else {
            return XCTFail("読み込み済みにならなかった")
        }
        XCTAssertEqual(loaded.faqItems.map(\.id), ["q3", "q1", "q2"])
        XCTAssertEqual(Set(loaded.faqItems.map(\.id)).count, loaded.faqItems.count)
    }

    func testRelatedPlaceKeepsCanonicalIDVerbatim() async {
        let place = GuidanceRelatedPlace(
            canonicalSpotID: CanonicalSpotID(rawValue: "Mb_F2_CR_2A"),
            displayName: "2A教室"
        )
        let store = GuidanceStore(
            client: .stub(article: { id in .fresh(makeTestArticle(id, relatedPlaces: [place])) })
        )

        await store.loadArticleIfNeeded(receptionID)

        guard case .loaded(let loaded) = store.articleState(for: receptionID) else {
            return XCTFail("読み込み済みにならなかった")
        }
        XCTAssertEqual(loaded.relatedPlaces.first?.canonicalSpotID.rawValue, "Mb_F2_CR_2A")
        XCTAssertNotEqual(
            loaded.relatedPlaces.first?.canonicalSpotID,
            CanonicalSpotID(rawValue: "mb_f2_cr_2a")
        )
    }

    /// レイアウトは `kind` で選ばれ、記事IDでは選ばれない。
    func testDetailLayoutIsSelectedByKindNotIdentifier() async {
        let items = [GuidanceFAQItem(id: "q", question: "Q", answerParagraphs: ["A"])]
        let idA = GuidanceArticleID(rawValue: "faq_alpha")
        let idB = GuidanceArticleID(rawValue: "totally_different_id")
        let store = GuidanceStore(
            client: .stub(article: { id in .fresh(makeTestArticle(id, kind: .faq, faqItems: items)) })
        )

        await store.loadArticleIfNeeded(idA)
        await store.loadArticleIfNeeded(idB)

        for id in [idA, idB] {
            guard case .loaded(let loaded) = store.articleState(for: id) else {
                return XCTFail("\(id.rawValue) が読み込まれなかった")
            }
            XCTAssertEqual(loaded.kind, .faq)
            XCTAssertEqual(loaded.faqItems.count, 1)
        }
    }

    /// 未提供の関連地点はボタン用のデータを作らず、説明文だけを持つ。
    func testUnresolvedRelatedPlaceProducesNoteInsteadOfPlace() async {
        let store = GuidanceStore(
            client: .stub(article: { id in
                .fresh(
                    GuidanceArticle(
                        id: id,
                        kind: .standard,
                        navigationTitle: "受付案内",
                        title: "受付案内",
                        updateStatus: .normal,
                        unresolvedRelatedPlaceNote: "地点IDが未確定です"
                    )
                )
            })
        )

        await store.loadArticleIfNeeded(receptionID)

        guard case .loaded(let loaded) = store.articleState(for: receptionID) else {
            return XCTFail("読み込み済みにならなかった")
        }
        XCTAssertTrue(loaded.relatedPlaces.isEmpty)
        XCTAssertEqual(loaded.unresolvedRelatedPlaceNote, "地点IDが未確定です")
    }
}

/// `@Sendable` クロージャから呼ぶため、テストクラスの外に置く。
private func makeTestArticle(
    _ id: GuidanceArticleID,
    kind: GuidanceArticleKind = .standard,
    updateStatus: GuidanceUpdateStatus = .normal,
    accessSegments: [GuidanceAccessSegment] = [],
    faqItems: [GuidanceFAQItem] = [],
    relatedPlaces: [GuidanceRelatedPlace] = []
) -> GuidanceArticle {
    GuidanceArticle(
        id: id,
        kind: kind,
        navigationTitle: id.rawValue,
        title: id.rawValue,
        updateStatus: updateStatus,
        relatedPlaces: relatedPlaces,
        accessSegments: accessSegments,
        faqItems: faqItems
    )
}
