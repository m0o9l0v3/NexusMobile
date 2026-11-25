import XCTest
@testable import Nexus

final class MapCardLayoutTests: XCTestCase {
    func testNoInsetWithoutCardOrBeforeLayout() {
        XCTAssertEqual(MapCardLayout.bottomInset(hasCard: false, cardHeight: 120, availableHeight: 700, searchHeight: 60), 0)
        XCTAssertEqual(MapCardLayout.bottomInset(hasCard: true, cardHeight: 120, availableHeight: 0, searchHeight: 0), 0)
    }

    func testInsetPlacesAttributionAboveMeasuredCard() {
        XCTAssertEqual(MapCardLayout.bottomInset(hasCard: true, cardHeight: 210, availableHeight: 700, searchHeight: 60), 226)
    }

    func testOversizedCardLeavesSpaceBelowSearchForMapControls() {
        let height = MapCardLayout.maximumCardHeight(availableHeight: 700, searchHeight: 80, showsMap: true)
        XCTAssertEqual(height, 516)
        let inset = MapCardLayout.bottomInset(hasCard: true, cardHeight: 1_000, availableHeight: 700, searchHeight: 80)
        XCTAssertEqual(inset, height + NexusTheme.spacing16)
        XCTAssertEqual(700 - 80 - inset, 88)
    }

    func testUnavailableMapGivesItsControlSpaceToTheDetailCard() {
        XCTAssertEqual(MapCardLayout.maximumCardHeight(availableHeight: 700, searchHeight: 80, showsMap: false), 604)
    }

    func testExpandedSearchCannotProduceNegativeHeights() {
        XCTAssertEqual(MapCardLayout.maximumCardHeight(availableHeight: 280, searchHeight: 310, showsMap: false), 0)
        XCTAssertEqual(MapCardLayout.bottomInset(hasCard: true, cardHeight: 500, availableHeight: 280, searchHeight: 310), 0)
    }
}
