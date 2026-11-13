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
/// お知らせは v1.0 では出さない（E2-5 改訂1 EV-D2）ため、お知らせの遷移先は持たない。
enum NotProvidedTopic: String, Hashable, Sendable, CaseIterable {
    case eventList

    var title: String {
        switch self {
        case .eventList:
            return "体験イベント一覧は未提供です"
        }
    }

    var detail: String {
        switch self {
        case .eventList:
            return "正式な体験イベント情報の供給元が決まり次第、この画面を提供します。"
        }
    }

    var navigationTitle: String {
        switch self {
        case .eventList:
            return "体験イベント"
        }
    }
}
