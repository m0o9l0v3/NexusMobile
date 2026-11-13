import SwiftUI

/// `AppRoute` を実画面へ解決する。各 `NavigationStack` の
/// `.navigationDestination(for: AppRoute.self)` から1箇所だけ呼ばれる。
struct AppDestinationView: View {
    let route: AppRoute
    let guidanceStore: GuidanceStore
    let eventListClient: EventListClient
    let routeStore: RouteRequestStore

    var body: some View {
        switch route {
        case .guidanceArticle(let articleID):
            GuidanceArticleView(articleID: articleID, store: guidanceStore)

        case .allEvents:
            EventListView(client: eventListClient, routeStore: routeStore)
        }
    }
}
