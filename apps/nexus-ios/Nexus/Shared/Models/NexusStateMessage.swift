import Foundation

/// 画面共通の状態メッセージ。
///
/// Home の `HomeStateMessage` と同形だが、Home 側の型は既存テスト・既存 View から
/// 参照されているため、この機能ブランチでは統合せず新規型として並置する。
/// `typealias` への集約は別コミットの後片付けとし、半端な移行状態を残さない。
struct NexusStateMessage: Equatable, Sendable {
    let title: String
    let detail: String?
    let systemImageName: String

    init(title: String, detail: String? = nil, systemImageName: String) {
        self.title = title
        self.detail = detail
        self.systemImageName = systemImageName
    }
}

/// 保存版（オフラインで表示している保存済みデータ）の説明。
///
/// 「保存版」は Home に合わせて一貫して `saved` と呼ぶ。`cached` とは呼ばない
/// ——キャッシュ層の実装を意味しないため。
struct NexusSavedMetadata: Equatable, Sendable {
    let title: String
    let detail: String?
    /// 保存版の bundle の版・公開日時・最終確認日時（E2-5 §6 規則7）。bundle 以外の保存版では nil。
    let bundleVersion: Int64?
    let publishedAt: Date?
    let lastConfirmedAt: Date?

    init(
        title: String,
        detail: String? = nil,
        bundleVersion: Int64? = nil,
        publishedAt: Date? = nil,
        lastConfirmedAt: Date? = nil
    ) {
        self.title = title
        self.detail = detail
        self.bundleVersion = bundleVersion
        self.publishedAt = publishedAt
        self.lastConfirmedAt = lastConfirmedAt
    }
}
