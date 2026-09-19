import XCTest
@testable import Nexus

/// 本番既定（`unconfigured` / `unavailable`）が、fixture の成功データに
/// すり替わっていないことを確認する。
@MainActor
final class ClientBoundaryTests: XCTestCase {

    func testUnconfiguredSearchClientThrowsForInitialAndSearch() async {
        let client = SearchClient.unconfigured

        do {
            _ = try await client.initialContent()
            XCTFail("初期取得が throw しなかった")
        } catch {}

        do {
            _ = try await client.search(.empty)
            XCTFail("検索が throw しなかった")
        } catch {}
    }

    func testUnconfiguredMapContentClientThrows() async {
        do {
            _ = try await MapContentClient.unconfigured.spotDetail(
                CanonicalSpotID(rawValue: "mb_f2_cr_2a")
            )
            XCTFail("地点詳細が throw しなかった")
        } catch {}
    }

    func testUnconfiguredGuidanceClientThrowsForTopAndArticle() async {
        let client = GuidanceClient.unconfigured

        do {
            _ = try await client.fetchTop()
            XCTFail("案内トップが throw しなかった")
        } catch {}

        do {
            _ = try await client.fetchArticle(GuidanceArticleID(rawValue: "reception"))
            XCTFail("案内記事が throw しなかった")
        } catch {}
    }

    func testUnconfiguredRouteHandlerReportsNotProvided() async {
        let outcome = await RouteRequestHandling.unconfigured.requestRoute(
            CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
            .map
        )

        guard case .unavailable(let message) = outcome else {
            return XCTFail("未提供結果にならなかった")
        }
        XCTAssertEqual(message.title, "経路案内は未提供です")
    }

    func testDefaultMapSurfaceProviderIsTheUnavailablePlaceholder() {
        XCTAssertEqual(MapSurfaceProvider.unavailable.identifier, "unavailable")
    }

    /// 既定構成では、どのストアも `.loaded` / `.saved` に到達しない。
    func testDefaultShellModelNeverReachesALoadedState() async {
        let model = AppShellModel(
            searchClient: .unconfigured,
            mapContentClient: .unconfigured,
            mapSurface: .unavailable,
            guidanceClient: .unconfigured,
            routeHandler: .unconfigured
        )

        await model.searchStore.loadInitialIfNeeded()
        await model.mapSearchStore.loadInitialIfNeeded()
        await model.guidanceStore.loadTopIfNeeded()
        await model.guidanceStore.loadArticleIfNeeded(GuidanceArticleID(rawValue: "reception"))
        await model.mapStore.select(
            MapSelection(
                canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
                eventID: nil,
                origin: .search
            )
        )
        await model.routeStore.requestRoute(to: CanonicalSpotID(rawValue: "mb_f2_cr_2a"), from: .map)

        for store in [model.searchStore, model.mapSearchStore] {
            switch store.state {
            case .failed:
                break
            default:
                XCTFail("検索が失敗以外の状態になった: \(store.state)")
            }
        }

        guard case .failed = model.guidanceStore.topState else {
            return XCTFail("案内トップが失敗以外の状態になった: \(model.guidanceStore.topState)")
        }
        guard case .failed = model.guidanceStore.articleState(
            for: GuidanceArticleID(rawValue: "reception")
        ) else {
            return XCTFail("案内記事が失敗以外の状態になった")
        }
        guard case .failed = model.mapStore.detailState else {
            return XCTFail("地点詳細が失敗以外の状態になった: \(model.mapStore.detailState)")
        }
        XCTAssertNil(model.routeStore.activeDestination)
        XCTAssertEqual(model.mapSurface.identifier, "unavailable")
    }
}
