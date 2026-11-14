import XCTest
@testable import Nexus

/// VoiceOver の読み上げ文（#78、`docs/verification/ios-a11y-check.md` の観点2）。
/// 中止は色ではなく文字で、読み上げの先頭で伝える。
final class AccessibilityTextTests: XCTestCase {
    private func homeEvent(
        timeContextText: String? = nil,
        isCancelled: Bool = false,
        cancelNote: String? = nil
    ) -> HomeEvent {
        HomeEvent(
            id: "slot-1",
            eventID: "event-1",
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
            category: "テクノロジー",
            title: "ドローン体験",
            timeText: "10:00〜11:30",
            timeContextText: timeContextText,
            locationName: "2A 教室",
            systemImageName: "airplane",
            isCancelled: isCancelled,
            cancelNote: cancelNote
        )
    }

    private func listSlot(isCancelled: Bool = false, cancelNote: String? = nil, modeText: String? = nil) -> EventListSlot {
        EventListSlot(
            id: "slot-1",
            eventID: "event-1",
            canonicalSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
            categoryID: "tech",
            categoryName: "テクノロジー",
            title: "ドローン体験",
            startText: "10:00",
            endText: "11:30",
            modeText: modeText,
            locationName: "2A 教室",
            isCancelled: isCancelled,
            cancelNote: cancelNote
        )
    }

    // MARK: - Home

    func testHomeEventCardReadsAllVisibleText() {
        XCTAssertEqual(
            homeEvent(timeContextText: "8月2日（月）").cardAccessibilityLabel,
            "テクノロジー、ドローン体験、8月2日（月）、10:00〜11:30、2A 教室"
        )
    }

    func testCancelledHomeEventCardStartsWithCancelled() {
        XCTAssertEqual(
            homeEvent(isCancelled: true, cancelNote: "機材の不調のため").cardAccessibilityLabel,
            "中止、テクノロジー、ドローン体験、10:00〜11:30、2A 教室、機材の不調のため"
        )
        XCTAssertTrue(homeEvent(isCancelled: true).cardAccessibilityLabel.hasPrefix("中止、"))
    }

    func testNextEventReadsDateContextAndCategory() {
        XCTAssertEqual(
            homeEvent(timeContextText: "8月2日（月）").nextEventAccessibilityLabel,
            "次の体験イベント、8月2日（月）、10:00〜11:30、テクノロジー、ドローン体験、2A 教室"
        )
        XCTAssertEqual(
            homeEvent().nextEventAccessibilityLabel,
            "次の体験イベント、10:00〜11:30、テクノロジー、ドローン体験、2A 教室"
        )
    }

    /// 同じ名前の「詳細」「マップで見る」が並ぶため、イベント名で区別する。
    func testCardButtonsNameTheEvent() {
        let event = homeEvent()
        XCTAssertEqual(event.detailsButtonAccessibilityLabel, "ドローン体験の詳細")
        XCTAssertEqual(event.mapButtonAccessibilityLabel, "ドローン体験をマップで見る")
    }

    // MARK: - すべてのイベント

    func testEventListRowReadsTimeRangeAndMode() {
        XCTAssertEqual(
            listSlot(modeText: "随時参加").accessibilityLabelText,
            "10:00から11:30、テクノロジー、ドローン体験、2A 教室、随時参加"
        )
        XCTAssertEqual(listSlot().mapButtonAccessibilityLabel, "ドローン体験をマップで見る")
    }

    func testCancelledEventListRowStartsWithCancelledAndReadsNote() {
        XCTAssertEqual(
            listSlot(isCancelled: true, cancelNote: "台風のため").accessibilityLabelText,
            "中止、10:00から11:30、テクノロジー、ドローン体験、2A 教室、台風のため"
        )
    }

    // MARK: - 地点詳細のイベント欄

    func testSpotEventSlotReadsCancelled() {
        let slot = SpotEventSlot(
            id: "slot-3",
            dateText: "8月2日",
            timeText: "13:00〜13:45",
            modeText: nil,
            venues: [],
            isCancelled: true,
            cancelNote: "台風のため2日目は中止します"
        )
        XCTAssertEqual(slot.timeAccessibilityText, "中止、8月2日、13:00〜13:45、台風のため2日目は中止します")
    }

    func testSpotEventSlotReadsMode() {
        let slot = SpotEventSlot(
            id: "slot-2",
            dateText: "8月1日",
            timeText: "10:00〜15:00",
            modeText: "終日・随時参加",
            venues: [],
            isCancelled: false,
            cancelNote: nil
        )
        XCTAssertEqual(slot.timeAccessibilityText, "8月1日、10:00〜15:00、終日・随時参加")
    }
}
