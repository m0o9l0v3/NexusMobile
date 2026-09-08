import SwiftUI

@main
struct NexusApp: App {
    private let homeClient: HomeClient

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-NexusHomePreview") {
            homeClient = .preview(result: .fresh(HomePreviewFixtures.loaded))
        } else {
            homeClient = .unconfigured
        }
#else
        homeClient = .unconfigured
#endif
    }

    var body: some Scene {
        WindowGroup {
            NexusAppShell(homeClient: homeClient)
        }
    }
}
