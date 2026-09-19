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

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-NexusPreviewData") {
            // Figma とシミュレーターを比較するための検討用データ。
            // Release ビルドには到達しない。
            homeClient = .preview(result: .fresh(HomePreviewFixtures.loaded))
            searchClient = .preview()
            mapContentClient = .preview()
            mapSurface = .unavailable
            guidanceClient = .preview()
            routeHandler = .unconfigured
        } else if arguments.contains("-NexusHomePreview") {
            homeClient = .preview(result: .fresh(HomePreviewFixtures.loaded))
            searchClient = .unconfigured
            mapContentClient = .unconfigured
            mapSurface = .unavailable
            guidanceClient = .unconfigured
            routeHandler = .unconfigured
        } else {
            homeClient = .unconfigured
            searchClient = .unconfigured
            mapContentClient = .unconfigured
            mapSurface = .unavailable
            guidanceClient = .unconfigured
            routeHandler = .unconfigured
        }

        // `-NexusPreviewScreen <name>` で比較したい画面を直接開く。
        (initialTab, initialGuidePath, initialMapSelection) = Self.previewEntryPoint(arguments)
#else
        homeClient = .unconfigured
        searchClient = .unconfigured
        mapContentClient = .unconfigured
        mapSurface = .unavailable
        guidanceClient = .unconfigured
        routeHandler = .unconfigured
        initialTab = .home
        initialGuidePath = []
        initialMapSelection = nil
#endif
    }

#if DEBUG
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
                    canonicalSpotID: CanonicalSpotID(rawValue: "mb_f2_cr_2a"),
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
        }
    }
}
