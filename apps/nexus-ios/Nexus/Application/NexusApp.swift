import SwiftUI

@main
struct NexusApp: App {
    private let homeClient: HomeClient
    private let searchClient: SearchClient
    private let mapContentClient: MapContentClient
    private let mapSurface: MapSurfaceProvider
    private let guidanceClient: GuidanceClient
    private let routeHandler: RouteRequestHandling
    private let initialTab: AppTab
    private let initialGuidePath: [AppRoute]
    private let initialMapSelection: MapSelection?
    /// 公開データの bundle の取得・保存一式。接続先が未設定なら nil（Map・探すは未接続のまま）。
    private let bundleRuntime: PublishedBundleRuntime?

    @Environment(\.scenePhase) private var scenePhase

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-NexusPreviewData") {
            // Figma とシミュレーターを比較するための検討用データ。
            // Release ビルドには到達しない。
            homeClient = .preview(result: .fresh(HomePreviewFixtures.loaded))
            searchClient = .preview()
            mapContentClient = .preview()
            mapSurface = Self.debugMapSurface(arguments)
            guidanceClient = .preview()
            routeHandler = .unconfigured
            bundleRuntime = nil
        } else if arguments.contains("-NexusHomePreview") {
            homeClient = .preview(result: .fresh(HomePreviewFixtures.loaded))
            searchClient = .unconfigured
            mapContentClient = .unconfigured
            mapSurface = Self.debugMapSurface(arguments)
            guidanceClient = .unconfigured
            routeHandler = .unconfigured
            bundleRuntime = nil
        } else {
            let runtime = Self.makeBundleRuntime()
            bundleRuntime = runtime
            homeClient = .unconfigured
            searchClient = runtime.map { .bundle(source: $0.source) } ?? .unconfigured
            mapContentClient = runtime.map { .bundle(source: $0.source) } ?? .unconfigured
            mapSurface = Self.debugMapSurface(arguments, bundleSource: runtime?.source)
            guidanceClient = .unconfigured
            routeHandler = .unconfigured
        }

        // `-NexusPreviewScreen <name>` で比較したい画面を直接開く。
        (initialTab, initialGuidePath, initialMapSelection) = Self.previewEntryPoint(arguments)
#else
        let runtime = Self.makeBundleRuntime()
        bundleRuntime = runtime
        homeClient = .unconfigured
        searchClient = runtime.map { .bundle(source: $0.source) } ?? .unconfigured
        mapContentClient = runtime.map { .bundle(source: $0.source) } ?? .unconfigured
        mapSurface = .unavailable
        guidanceClient = .unconfigured
        routeHandler = .unconfigured
        initialTab = .home
        initialGuidePath = []
        initialMapSelection = nil
#endif
    }

    /// Info.plist の接続先（M1-3）が設定されていれば、bundle の取得・保存一式を作る。
    private static func makeBundleRuntime() -> PublishedBundleRuntime? {
#if DEBUG
        // 単体試験はアプリを host にして動くため、開発者の手元の接続先へ通信しない。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return nil
        }
#endif
        return NexusAPIConfiguration(infoDictionary: Bundle.main.infoDictionary)
            .map { PublishedBundleRuntime(configuration: $0) }
    }

    /// 起動時と前面復帰時だけ更新を確認する（E2-5 §6 規則10）。背面では再試行しない。
    private func handleScenePhase(_ phase: ScenePhase) {
        guard let scheduler = bundleRuntime?.scheduler else { return }
        switch phase {
        case .active:
            Task { await scheduler.becameActive() }
        case .background:
            Task { await scheduler.enteredBackground() }
        default:
            break
        }
    }

#if DEBUG
    /// DEBUG のみの地図の描画面。どちらの引数も無ければ、本番と同じく未提供の表示にする。
    /// - `-NexusMapKitCheck`：#24 の通信断の表示確認用に、検証用の14棟を MapKit で描く。
    /// - `-NexusMapKitBundle`：接続先が設定されていれば、保存済みの bundle を MapKit で描く（#26、M1 統合受入の予行）。
    private static func debugMapSurface(
        _ arguments: [String],
        bundleSource: PublishedBundleSource? = nil
    ) -> MapSurfaceProvider {
        if arguments.contains("-NexusMapKitCheck") {
            return .mapKit(content: .offlineCheck, provisionalNotice: CampusMapContent.offlineCheckNotice)
        }
        if arguments.contains("-NexusMapKitBundle"), let bundleSource {
            return .debugBundle(source: bundleSource)
        }
        return .unavailable
    }

    /// Figma 比較用の入口。DEBUG のみ。
    private static func previewEntryPoint(
        _ arguments: [String]
    ) -> (AppTab, [AppRoute], MapSelection?) {
        guard let index = arguments.firstIndex(of: "-NexusPreviewScreen"),
              arguments.indices.contains(index + 1)
        else {
            return (.home, [], nil)
        }

        switch arguments[index + 1] {
        case "search":
            return (.search, [], nil)
        case "map":
            return (.map, [], nil)
        case "spotDetail":
            return (
                .map,
                [],
                MapSelection(
                    canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
                    eventID: nil,
                    origin: .search
                )
            )
        case "guidance":
            return (.guide, [], nil)
        case "guidanceStandard":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.receptionID)], nil)
        case "guidanceHelp":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.lostID)], nil)
        case "guidanceHelpHealth":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.healthID)], nil)
        case "guidanceAccess":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.accessID)], nil)
        case "guidanceFAQ":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.faqID)], nil)
        case "guidanceRelatedPlace":
            return (.guide, [.guidanceArticle(GuidancePreviewFixtures.facilityID)], nil)
        default:
            return (.home, [], nil)
        }
    }
#endif

    var body: some Scene {
        WindowGroup {
            NexusAppShell(
                homeClient: homeClient,
                searchClient: searchClient,
                mapContentClient: mapContentClient,
                mapSurface: mapSurface,
                guidanceClient: guidanceClient,
                routeHandler: routeHandler,
                initialTab: initialTab,
                initialGuidePath: initialGuidePath,
                initialMapSelection: initialMapSelection
            )
            .onChange(of: scenePhase, initial: true) { _, phase in
                handleScenePhase(phase)
            }
        }
    }
}
