import Foundation

/// `NavigationStack` へ実際に push される画面だけを列挙する。
///
/// 「探す」の 初期 → 入力中 → 結果 は同一画面内の状態遷移（`SearchPhase`）であり、
/// Map の地点詳細は地図上のカード（`MapStore.selection`）なので、どちらもここには現れない。
/// Figma もその構造になっている。
enum AppRoute: Hashable, Sendable {
    case guidanceArticle(GuidanceArticleID)
    case notProvided(NotProvidedTopic)
}

/// Figma に設計が存在せず、正式データも未提供の遷移先。
///
/// Home の「すべて見る」等はリンクとして存在するが、遷移先画面は設計されていない。
/// 無反応のボタンにも、でっち上げた画面にもせず、未提供であることを明示する。
enum NotProvidedTopic: String, Hashable, Sendable, CaseIterable {
    case announcementList
    case announcementDetail
    case eventList

    var title: String {
        switch self {
        case .announcementList:
            return "お知らせ一覧は未提供です"
        case .announcementDetail:
            return "お知らせ詳細は未提供です"
        case .eventList:
            return "体験イベント一覧は未提供です"
        }
    }

    var detail: String {
        switch self {
        case .announcementList, .announcementDetail:
            return "正式なお知らせの供給元と更新担当が決まり次第、この画面を提供します。"
        case .eventList:
            return "正式な体験イベント情報の供給元が決まり次第、この画面を提供します。"
        }
    }

    var navigationTitle: String {
        switch self {
        case .announcementList:
            return "お知らせ"
        case .announcementDetail:
            return "お知らせ詳細"
        case .eventList:
            return "体験イベント"
        }
    }
}
