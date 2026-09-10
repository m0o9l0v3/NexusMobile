import Foundation

/// 検索画面へ入るときの意図。
///
/// v04「Home検索と『探す』の共通動作案」の3挙動を型で区別する:
/// - Home の検索欄 → 以前の条件を解除し、入力にフォーカスする
/// - Home のカテゴリ → 条件を明示した一覧を出し、キーボードは自動表示しない
/// - 探すタブを直接再訪 → 直前の状態を保持する（要求そのものを送らない）
struct SearchEntryIntent: Equatable, Hashable, Sendable {
    let focusesInput: Bool
    let clearsPreviousConditions: Bool

    static let browse = SearchEntryIntent(focusesInput: false, clearsPreviousConditions: false)
    static let newSearch = SearchEntryIntent(focusesInput: true, clearsPreviousConditions: true)
}

struct HomeSearchRequest: Equatable, Sendable {
    let query: String?
    let categoryID: String?
    /// 既定値付きの `var`。`let` にすると memberwise initializer から除外され、
    /// 既存の `HomeSearchRequest(query:categoryID:)` 呼び出しが壊れる。
    var intent: SearchEntryIntent = .browse

    static let empty = HomeSearchRequest(query: nil, categoryID: nil)

    /// Home の検索欄から新規検索を始める場合。
    static let focusedNewSearch = HomeSearchRequest(
        query: nil,
        categoryID: nil,
        intent: .newSearch
    )
}

/// 画面から送られる遷移要求。View 自身はどのタブへ行くかを決めない。
///
/// 消費するのは `AppRouteCoordinator` のみ。
enum AppRouteRequest: Equatable, Sendable {
    case search(HomeSearchRequest)
    case allAnnouncements
    case announcementDetails(id: String, canonicalSpotID: CanonicalSpotID?)
    case allEvents
    case eventDetails(eventID: String, canonicalSpotID: CanonicalSpotID)
    case spotDetails(canonicalSpotID: CanonicalSpotID)
    case route(destinationSpotID: CanonicalSpotID)
    case guidanceTop
    case guidanceArticle(articleID: GuidanceArticleID)
}
