import XCTest
@testable import Nexus

@MainActor
final class SearchMapIntegrationTests: XCTestCase {
    private func makeStore(_ source: PublishedBundleSource, surface: SearchSurface = .home) -> SearchStore {
        SearchStore(client: .bundle(source: source), history: SearchHistoryStore(), surface: surface)
    }

    func testNameNormalizationAcrossScriptsWidthsAndWhitespace() async throws {
        let groups = [
            ["ガクモン", "ｶﾞｸﾓﾝ", "がくもん"],
            ["ダヴィンチ", "ﾀﾞｳﾞｨﾝﾁ", "だゔぃんち"],
            ["パビリオン", "ﾊﾟﾋﾞﾘｵﾝ", "ぱびりおん"],
            ["がっこう", "か\u{3099}っこう", "ｶﾞｯｺｳ"],
            ["ホール", "ほーる", "ﾎｰﾙ"],
            ["Da Vinci Hall", "Ｄａ　Ｖｉｎｃｉ  Ｈａｌｌ", " da\tvinci\nhall "],
        ]
        for group in groups {
            XCTAssertEqual(Set(group.map(SpotNameMatcher.normalize)).count, 1, group.joined(separator: " / "))
        }

        let client = SearchClient.bundle(source: SearchCheckFixtures.normal.source)
        for (text, id) in [("ﾀﾞｳﾞｨﾝﾁ", "dvh"), ("Ｄａ　Ｖｉｎｃｉ", "dvh"), ("dvh", "dvh"),
                           ("ＣＴＣ２", "ctc2"), ("はんがーa", "hgr_a"), ("にーえー", "mb_2f_cl_001")] {
            let result = try await client.search(.init(text: text))
            guard case .fresh(let snapshot) = result else { return XCTFail(text) }
            XCTAssertEqual(snapshot.spots.map(\.id.rawValue), [id], text)
        }
    }

    func testIDsAndLegacyAliasesNeverBecomeNameMatchesOrSubstituteForCanonicalID() async throws {
        let source = SearchCheckFixtures.normal.source
        let client = SearchClient.bundle(source: source)
        for id in ["mb_2f_cl_001", "MB_2F_CL_001", "hgr_a", "mb_f2_cr_2a"] {
            let result = try await client.search(.init(text: id))
            XCTAssertEqual(result, .empty(SearchClient.noMatchMessage), id)
        }
        let map = MapStore(client: .bundle(source: source))
        for id in ["MB_2F_CL_001", "mb_f2_cr_2a", "missing"] {
            let spotID = CanonicalSpotID(rawValue: id)
            await map.selectOnMap(spotID)
            XCTAssertEqual(map.detailState, .unknown(spotID))
        }
    }

    func testCategoriesKeepPublishedOrderAndClearBackToAllIncludingNilKind() async {
        let store = makeStore(SearchCheckFixtures.normal.source)
        for (category, ids) in [
            (SearchCategoryID.classroom, ["mb_2f_cl_001", "mb_1f_cl_002"]),
            (.facility, ["mb", "hgr_a", "dvh", "ctc2", "ptb", "mb_ent_001", "campus_lm_001",
                         "mb_1f_rm_001", "mb_2f_rm_001", "mb_1f_rm_003"]),
            (.service, ["ctc2_1f_rm_001", "mb_1f_rm_002", "campus_unplaced_001"]),
        ] {
            await store.selectCategory(category)
            guard case .results(let results) = store.state else { return XCTFail("カテゴリ結果が必要") }
            XCTAssertEqual(results.spots.map(\.id.rawValue), ids)
        }
        await store.apply(.init(query: "2A", categoryID: "unknown"))
        XCTAssertEqual(store.unresolvedCategoryID, "unknown")
        await store.clearConditions()
        guard case .initial(let initial) = store.state else { return XCTFail("全地点に戻る") }
        XCTAssertEqual(initial.totalCount, 16)
        XCTAssertTrue(initial.spots.contains { $0.id.rawValue == "sab" && $0.kind == nil })
        XCTAssertNil(store.unresolvedCategoryID)
    }

    func testMissingLocationComponentsLeaveNoEmptySeparatorsOrVoiceOverParts() {
        for building in [nil, "", "　 \n"] {
            let spot = SpotSummary(canonicalSpotID: .init(rawValue: "room"), displayName: "部屋",
                                   kind: .facility, buildingName: building, floorName: " 2F\n")
            XCTAssertEqual(spot.locationText, "2F")
            XCTAssertEqual(spot.supplementaryText, "施設・2F")
            XCTAssertEqual(spot.accessibilityLabelText, "部屋、施設、2F")
        }
        let spot = SpotSummary(canonicalSpotID: .init(rawValue: "x"), displayName: "地点",
                               kind: nil, buildingName: " ", floorName: "\t")
        XCTAssertEqual(spot.supplementaryText, "")
        XCTAssertEqual(spot.accessibilityLabelText, "地点、場所は未提供")
    }

    func testEachSameNameResultOpensItsOwnMapDetailAndFocusWithoutChangingGuidance() async throws {
        let source = SearchCheckFixtures.normal.source
        let content = CampusMapContent(bundle: try XCTUnwrap(SearchCheckFixtures.normal.snapshot).bundle)
        let harness = TestHarness(searchClient: .bundle(source: source), mapContentClient: .bundle(source: source),
                                  routeHandler: .alwaysAccepting)
        let store = harness.searchStore
        await harness.handle(.search(.focusedNewSearch), from: .home)
        let pairs = [
            ("たもくてきしつ", ["mb_1f_rm_001", "mb_2f_rm_001"], ["施設・教室棟・1F", "施設・教室棟・2F"], ["mb", "mb"]),
            ("うけつけ", ["ctc2_1f_rm_001", "mb_1f_rm_002"], ["サービス・CTC2・1F", "サービス・教室棟・1F"], ["ctc2", "mb"]),
            ("実習室", ["mb_1f_cl_002", "mb_1f_rm_003"], ["教室・教室棟・1F", "施設・教室棟・1F"], ["mb", "mb"]),
        ]
        for (query, ids, labels, buildings) in pairs {
            store.draftText = query
            await store.updateHomeResults(for: query)
            let original = store.state
            guard case .results(let results) = original else { return XCTFail(query) }
            XCTAssertEqual(results.spots.map(\.id.rawValue), ids)
            XCTAssertEqual(results.spots.map(\.supplementaryText), labels)
            for (index, spot) in results.spots.enumerated() {
                harness.mapStore.isSearchActive = true
                store.beginEditing()
                store.endEditing()
                let destination = harness.routeStore.activeDestination
                await harness.handle(.spotDetails(canonicalSpotID: spot.id), from: .home)
                XCTAssertEqual(harness.router.selectedTab, .map)
                XCTAssertFalse(harness.mapStore.isSearchActive)
                XCTAssertEqual(harness.routeStore.activeDestination, destination)
                guard case .loaded(let detail) = harness.mapStore.detailState else { return XCTFail(query) }
                XCTAssertEqual(detail.summary, spot)
                let focus = harness.mapStore.surfaceContext().focusedSpotID
                XCTAssertEqual(CampusMapFocus.target(for: focus, in: content)?.spotID, spot.id)
                XCTAssertEqual(CampusMapFocus.highlightedBuildingID(for: focus, in: content), buildings[index])
                harness.router.activate(.home)
                XCTAssertTrue(store.isHomeSearchActive)
                XCTAssertEqual(store.committedQuery, .init(text: query))
                XCTAssertEqual(store.draftText, query)
                XCTAssertEqual(store.phase, .results)
                XCTAssertEqual(store.state, original)
                if destination == nil {
                    await harness.handle(.route(destinationSpotID: .init(rawValue: "hgr_a")), from: .map)
                    XCTAssertEqual(harness.routeStore.activeDestination?.canonicalSpotID.rawValue, "hgr_a")
                }
            }
        }
    }

    func testUnplacedResultOpensDetailWithoutCameraPinOrBuilding() async throws {
        let fixture = SearchCheckFixtures.normal
        let content = CampusMapContent(bundle: try XCTUnwrap(fixture.snapshot).bundle)
        let harness = TestHarness(searchClient: .bundle(source: fixture.source), mapContentClient: .bundle(source: fixture.source))
        harness.searchStore.draftText = "unplaced"
        await harness.searchStore.submit()
        guard case .results(let result) = harness.searchStore.state else { return XCTFail("検索結果が必要") }
        let spot = try XCTUnwrap(result.spots.first)
        await harness.handle(.spotDetails(canonicalSpotID: spot.id), from: .home)
        guard case .loaded(let detail) = harness.mapStore.detailState else { return XCTFail("詳細が必要") }
        XCTAssertEqual(detail.summary, spot)
        XCTAssertEqual(spot.id.rawValue, "campus_unplaced_001")
        XCTAssertTrue(spot.accessibilityLabelText.hasSuffix("場所は未提供"))
        XCTAssertNil(CampusMapFocus.pin(for: spot.id, in: content))
        XCTAssertNil(CampusMapFocus.highlightedBuildingID(for: spot.id, in: content))
        XCTAssertNil(CampusMapFocus.region(for: spot.id, in: content, visibleLatitudeDelta: nil))
    }

    func testAbsenceAtInitialLoadAndAfterSubmitting() async {
        for reason in [PublishedBundleAbsence.notPublished, .updateRequired, .checkFailed, .unknown] {
            let client = SearchClient.bundle(source: .fixed(nil, absence: reason))
            let store = SearchStore(client: client, history: SearchHistoryStore(), surface: .home)
            let expected: SearchViewState = switch reason {
            case .notPublished: .empty(SearchClient.noPublishedSpotsMessage, saved: nil)
            case .updateRequired: .failed(client.updateRequiredMessage)
            case .checkFailed, .unknown: .failed(client.failureMessage)
            }
            await store.loadInitialIfNeeded()
            XCTAssertEqual(store.state, expected)
            store.draftText = "dvh"
            await store.submit()
            XCTAssertEqual(store.state, expected)
        }
    }

    func testValidatedFixturesSavedInitialResultsEmptyAndDetail() async throws {
        for fixture in [SearchCheckFixtures.normal, .saved, .empty] {
            let snapshot = try await fixture.source.current()
            let stored = try XCTUnwrap(snapshot)
            XCTAssertEqual(stored.bundle.meta.schemaVersion, "2.1.0")
            XCTAssertEqual(stored.bundle.spots.count, fixture == .empty ? 0 : 16)
            XCTAssertEqual(stored.isConfirmedLatest, fixture != .saved)
        }
        let map = try XCTUnwrap(SearchCheckFixtures.normal.snapshot?.bundle.map)
        let points = map.geojson.features.filter { $0.featureType == "room" || $0.featureType == "landmark" }
        XCTAssertEqual(points.count, 8)
        for feature in points {
            XCTAssertNil(feature.name, feature.id)
        }

        let empty = makeStore(SearchCheckFixtures.empty.source)
        await empty.loadInitialIfNeeded()
        XCTAssertEqual(empty.state, .empty(SearchClient.noPublishedSpotsMessage, saved: nil))

        let source = SearchCheckFixtures.saved.source
        let store = makeStore(source, surface: .map)
        await store.loadInitialIfNeeded()
        guard case .saved(let initial, let metadata) = store.state else { return XCTFail("保存版の初期状態") }
        XCTAssertEqual(initial.spots.count, 16)
        XCTAssertFalse(store.hasActiveConditions)
        store.draftText = "dvh"
        await store.submit()
        guard case .saved(let matches, let saved) = store.state else { return XCTFail("保存版の結果") }
        XCTAssertEqual(saved, metadata)
        let spot = try XCTUnwrap(matches.spots.first)
        let result = try await MapContentClient.bundle(source: source).spotDetail(spot.id)
        guard case .saved(let detail, let detailMetadata) = result else { return XCTFail("保存版の詳細") }
        XCTAssertEqual(detail.summary, spot)
        XCTAssertEqual(detailMetadata, metadata)
        store.draftText = "missing"
        await store.submit()
        XCTAssertEqual(store.state, .empty(SearchClient.noMatchMessage, saved: metadata))
    }

    func testRetryRechecksFailureAndBoundaryReloadOnlyReads() async {
        let probe = SearchSourceProbe()
        let store = makeStore(probe.source)
        await store.loadInitialIfNeeded()
        guard case .failed = store.state else { return XCTFail("初回は失敗") }
        await store.reloadIfLoaded()
        var count = await probe.rechecks
        XCTAssertEqual(count, 0)
        await store.retry()
        guard case .initial = store.state else { return XCTFail("再試行で復旧") }
        await store.retry()
        await store.reloadIfLoaded()
        count = await probe.rechecks
        XCTAssertEqual(count, 1)
    }

    func testMapSearchRetryChangesPinnedContentOnlyWhenMapAdvances() async {
        let probe = SearchSourceProbe()
        let pin = PinnedBundleSource(upstream: probe.source, now: { PinnedFixtures.confirmedAt })
        let search = makeStore(pin.source, surface: .map)
        let map = MapStore(client: .bundle(source: pin.source), snapshotBoundary: .pinned(pin), overlaySearch: search)
        search.draftText = "にーえー"
        await search.submit()
        let id = CanonicalSpotID(rawValue: "mb_2f_cl_001")
        await map.selectOnMap(id)
        guard case .failed = search.state, case .failed = map.detailState else { return XCTFail("初回は版がない") }

        await search.retry()
        guard case .failed = search.state else { return XCTFail("確認した版への切替は Map が行う") }
        XCTAssertEqual(map.contentRevision, 0)
        await map.mapContentRetried()
        guard case .results(let result) = search.state, case .loaded(let detail) = map.detailState else {
            return XCTFail("版切替で地図・検索・開いていた詳細を読み直す")
        }
        XCTAssertEqual(map.contentRevision, 1)
        XCTAssertEqual(result.spots, [detail.summary])
        XCTAssertEqual(detail.summary.id, id)
        XCTAssertEqual(search.committedQuery, .init(text: "にーえー"))
        let count = await probe.rechecks
        XCTAssertEqual(count, 1)
    }

    func testQuietRefreshReplacesFreshResultsWithNewVersionWhileEditing() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let store = makeStore(upstream.source)
        await store.apply(.init(query: "2A", categoryID: "future_kind"))
        guard case .results(let first) = store.state else { return XCTFail("版1の検索結果が必要") }
        XCTAssertEqual(first.spots.map(\.displayName), [PinnedFixtures.roomName(version: 1)])
        store.beginEditing()
        store.draftText = "別の入力途中"
        let history = store.historyEntries
        XCTAssertEqual(history, [.init(text: "2A")])

        await upstream.set(try PinnedFixtures.snapshot(version: 2))
        await store.refreshAfterBundleUpdate()
        guard case .results(let next) = store.state else { return XCTFail("版2の検索結果が必要") }
        XCTAssertEqual(next.spots.map(\.displayName), [PinnedFixtures.roomName(version: 2)])
        XCTAssertEqual(store.committedQuery, .init(text: "2A"))
        XCTAssertEqual(store.draftText, "別の入力途中")
        XCTAssertEqual(store.phase, .focused)
        XCTAssertEqual(store.unresolvedCategoryID, "future_kind")
        XCTAssertEqual(store.historyEntries, history)
    }

    func testQuietRefreshMarksFreshResultsAsSavedWhenVersionIsUnconfirmed() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let store = makeStore(upstream.source)
        store.draftText = "2A"
        await store.submit()
        guard case .results(let first) = store.state else { return XCTFail("版1の検索結果が必要") }

        await upstream.set(try PinnedFixtures.snapshot(version: 1, isConfirmedLatest: false))
        await store.refreshAfterBundleUpdate()
        guard case .saved(let saved, let metadata) = store.state else { return XCTFail("保存版の表示が必要") }
        XCTAssertEqual(saved, first)
        XCTAssertEqual(metadata.bundleVersion, 1)
    }

    func testQuietRefreshKeepsFreshResultsOnReadFailure() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let store = makeStore(upstream.source)
        store.draftText = "2A"
        await store.submit()
        guard case .results(let first) = store.state else { return XCTFail("版1の検索結果が必要") }

        await upstream.fail()
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, .results(first))
    }

    func testQuietRefreshUpdatesInitialAndEmptyLists() async throws {
        let upstream = MutableUpstream(SearchCheckFixtures.empty.snapshot)
        let store = makeStore(upstream.source)
        await store.loadInitialIfNeeded()
        XCTAssertEqual(store.state, .empty(SearchClient.noPublishedSpotsMessage, saved: nil))

        await upstream.set(try PinnedFixtures.snapshot(version: 1))
        await store.refreshAfterBundleUpdate()
        guard case .initial(let initial) = store.state else { return XCTFail("公開後は初期一覧を表示") }
        XCTAssertFalse(initial.spots.isEmpty)
        await upstream.set(SearchCheckFixtures.empty.snapshot)
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, .empty(SearchClient.noPublishedSpotsMessage, saved: nil))
    }

    func testQuietRefreshLeavesUserSearchInFlight() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let store = makeStore(upstream.source)
        let gate = TestGate()
        await upstream.gateNextRead(gate)
        store.draftText = "2A"
        let submit = Task { await store.submit() }
        await gate.waitUntilWaiting()
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, .loading)

        await gate.open()
        await submit.value
        guard case .results = store.state else { return XCTFail("利用者が確定した結果を表示") }
        XCTAssertEqual(store.historyEntries, [.init(text: "2A")])
    }

    func testQuietRefreshPreservesConditionsHistoryDraftAndSavedContentOnFailure() async {
        let probe = MutableUpstream(nil)
        let store = makeStore(probe.source)
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, .idle)
        await store.apply(.init(query: "dvh", categoryID: "future_kind"))
        guard case .failed = store.state else { return XCTFail("初回は失敗") }
        await probe.set(SearchCheckFixtures.saved.snapshot)
        await store.refreshAfterBundleUpdate()
        guard case .saved = store.state else { return XCTFail("保存版で復旧") }
        await store.submit()
        store.beginEditing()
        store.draftText = "入力途中"
        let saved = store.state
        let history = store.historyEntries
        XCTAssertEqual(history, [.init(text: "dvh")])
        await probe.set(nil)
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, saved)
        await probe.set(SearchCheckFixtures.normal.snapshot)
        await store.refreshAfterBundleUpdate()
        guard case .results(let results) = store.state else { return XCTFail("最新版に昇格") }
        XCTAssertEqual(results.spots.map(\.id.rawValue), ["dvh"])
        XCTAssertEqual(store.committedQuery, .init(text: "dvh"))
        XCTAssertEqual(store.unresolvedCategoryID, "future_kind")
        XCTAssertEqual(store.draftText, "入力途中")
        XCTAssertEqual(store.phase, .focused)
        XCTAssertEqual(store.historyEntries, history)
    }

    func testQuietRefreshKeepsSavedEmptyAndDiscardsOlderInFlightResult() async {
        let probe = MutableUpstream(SearchCheckFixtures.saved.snapshot)
        let gate = TestGate()
        let store = makeStore(probe.source)
        store.draftText = "missing"
        await store.submit()
        let saved = store.state
        guard case .empty(_, saved: .some) = saved else { return XCTFail("保存版の0件") }
        await probe.set(nil)
        await store.refreshAfterBundleUpdate()
        XCTAssertEqual(store.state, saved)
        await probe.set(SearchCheckFixtures.normal.snapshot)
        await probe.gateNextRead(gate)
        let refresh = Task { await store.refreshAfterBundleUpdate() }
        await gate.waitUntilWaiting()
        XCTAssertEqual(store.state, saved)
        store.draftText = "dvh"
        await store.submit()
        let newest = store.state
        await gate.open()
        await refresh.value
        XCTAssertEqual(store.state, newest)
        XCTAssertEqual(store.committedQuery, .init(text: "dvh"))
    }
}

private actor SearchSourceProbe {
    var snapshot: PublishedBundleSnapshot?
    var rechecks = 0
    func recover() {
        rechecks += 1
        snapshot = SearchCheckFixtures.normal.snapshot
    }
    nonisolated var source: PublishedBundleSource {
        .init(current: { await self.snapshot }, absence: { .checkFailed }, recheck: { await self.recover() })
    }
}
