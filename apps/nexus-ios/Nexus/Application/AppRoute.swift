import Foundation

/// `NavigationStack` へ実際に push される画面だけを列挙する。
///
/// 「探す」の 初期 → 入力中 → 結果 は同一画面内の状態遷移（`SearchPhase`）であり、
/// Map の地点詳細は地図上のカード（`MapStore.selection`）なので、どちらもここには現れない。
/// Figma もその構造になっている。
enum AppRoute: Hashable, Sendable {
    case guidanceArticle(GuidanceArticleID)
    /// 「すべてのイベント」（Home v1.0 下書き C）。Home の「すべて見る」から開く。
    case allEvents
}
