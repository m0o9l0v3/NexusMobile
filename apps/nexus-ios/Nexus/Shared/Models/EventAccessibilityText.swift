import Foundation

// VoiceOver の読み上げ文（#78）。View の中に置くと単体試験で確かめられないため、モデルの拡張にまとめる。
// 中止の枠は、色や記号に頼らず読み上げの先頭で「中止」と伝える（E2-5 改訂1 EV-O1）。

extension HomeEvent {
    /// Home「この後のイベント」のカード本体。
    var cardAccessibilityLabel: String {
        let time = [timeContextText, timeText].compactMap { $0 }.joined(separator: "、")
        let base = "\(category)、\(title)、\(time)、\(locationName)"
        guard isCancelled else { return base }
        return "中止、" + base + (cancelNote.map { "、\($0)" } ?? "")
    }

    /// Home「次のイベント」。別の日・終日・随時参加の文言も読み上げる（見た目と同じ情報にする）。
    var nextEventAccessibilityLabel: String {
        let parts: [String?] = ["次の体験イベント", timeContextText, timeText, category, title, locationName]
        return parts.compactMap { $0 }.joined(separator: "、")
    }

    /// カード下の「詳細」。同じ名前のボタンが並ぶため、イベント名を添えて区別する。
    var detailsButtonAccessibilityLabel: String { "\(title)の詳細" }

    /// カード下の「マップで見る」。
    var mapButtonAccessibilityLabel: String { "\(title)をマップで見る" }
}

extension EventListSlot {
    /// 「すべてのイベント」の行。
    var accessibilityLabelText: String {
        let parts: [String?] = [
            isCancelled ? "中止" : nil,
            "\(startText)から\(endText)",
            categoryName,
            title,
            locationName,
            modeText,
            isCancelled ? cancelNote : nil,
        ]
        return parts.compactMap { $0 }.joined(separator: "、")
    }

    /// 行に重ねた「マップで見る」。
    var mapButtonAccessibilityLabel: String { "\(title)をマップで見る" }
}

extension SpotEventSlot {
    /// 地点詳細のイベント欄の枠（日時・参加の形・中止）。
    var timeAccessibilityText: String {
        let base = [dateText, timeText, modeText].compactMap { $0 }.joined(separator: "、")
        guard isCancelled else { return base }
        return "中止、" + base + (cancelNote.map { "、\($0)" } ?? "")
    }
}
