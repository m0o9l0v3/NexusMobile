import Foundation

/// 国土地理院の測量成果（基盤地図情報）の出典表記（E1-4 改訂4 K-3 §4.1・§4.2、M1 v1.0 仕様決定 テーマ2）。
///
/// 測量法第 30 条の使用承認は取得済み（学校事務局経由）。事務局から承認番号の通知を受け取り次第、
/// `approvalNumber` をここ 1 か所で設定すると、メイン地図画面・経路プレビューのミニ地図・
/// 案内タブ「このアプリについて」の出典表記が一括で承認番号付き表記へ切り替わる。
/// 承認書で別途文言の指定がある場合は、このファイルの生成メソッドをそのまま承認書の文言へ合わせる。
enum GSIAttribution {
    /// 測量法第 30 条の承認番号（例: `"令8情使、第XXX号"`）。
    /// 学校事務局から承認番号の通知を受け取るまでは `nil` とし、承認番号を推測・仮置きしない。
    static let approvalNumber: String? = nil

    /// メイン地図画面下部に 1 行で常時表示する短い出典表記（K-3 §4.2）。
    static var mapShortNotice: String {
        mapShortNotice(approvalNumber: approvalNumber)
    }

    /// 経路プレビューのミニ地図下に表示する短い出典表記。
    static var routePreviewNotice: String {
        mapShortNotice(approvalNumber: approvalNumber)
    }

    /// 案内タブ「このアプリについて」に掲載する測量法第 30 条に基づく出典表記（K-3 §4.1）。
    static var aboutParagraphs: [String] {
        fullNoticeParagraphs(approvalNumber: approvalNumber)
    }

    /// 承認番号の有無に応じて地図画面用の 1 行表記を組み立てる。
    static func mapShortNotice(approvalNumber: String?) -> String {
        guard let normalized = normalizedApprovalNumber(approvalNumber) else {
            return "建物の出典：国土地理院"
        }
        return "建物：国土地理院 基盤地図情報（承認番号 \(normalized)）を使用・加工"
    }

    /// 承認番号の有無に応じて案内画面用の全文段落を組み立てる（K-3 §4.1）。
    static func fullNoticeParagraphs(approvalNumber: String?) -> [String] {
        guard let normalized = normalizedApprovalNumber(approvalNumber) else {
            return [
                "この地図の作成に当たっては、国土地理院の基盤地図情報（建築物の外周線・道路縁）を使用しました。",
                "建物の形の一部は、基盤地図情報を基準に独自に測量して作成しました。",
            ]
        }
        return [
            "この地図の作成に当たっては、国土地理院長の承認を得て、同院の基盤地図情報（建築物の外周線・道路縁）を使用した。（承認番号　\(normalized)）",
            "建物の形の一部は、基盤地図情報を基準に独自に測量して作成した。",
        ]
    }

    /// 地図表示状態に応じてメイン地図画面に出典を表示するかを決める。
    /// 地図を描画している間（`loaded`）だけ常時表示し、読込中・未公開・取得失敗・失効などの
    /// 状態表示（`MapSurfaceStateView`）のみが出ている間は表示しない（K-3 §4.2）。
    static func showsMapAttribution(for state: MapContentState) -> Bool {
        state.isLoaded
    }

    /// VoiceOver 向けの読み上げラベル。
    static func accessibilityLabel(for notice: String = mapShortNotice) -> String {
        notice
    }

    private static func normalizedApprovalNumber(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
