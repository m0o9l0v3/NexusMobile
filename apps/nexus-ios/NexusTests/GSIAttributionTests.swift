import XCTest
@testable import Nexus

/// 国土地理院の出典表記・表示条件・レイアウト余白の単体テスト（K-3 §4.1・§4.2、#26・#85）。
final class GSIAttributionTests: XCTestCase {
    // MARK: - 文言と承認番号差し替え

    func testPendingApprovalUsesShortNoticeWithoutFabricatingApprovalNumber() {
        XCTAssertNil(GSIAttribution.approvalNumber)
        XCTAssertEqual(GSIAttribution.mapShortNotice, "建物の出典：国土地理院")
        XCTAssertEqual(GSIAttribution.routePreviewNotice, GSIAttribution.mapShortNotice)
        XCTAssertFalse(GSIAttribution.mapShortNotice.contains("承認番号"))
        XCTAssertEqual(GSIAttribution.aboutParagraphs, [
            "この地図の作成に当たっては、国土地理院の基盤地図情報（建築物の外周線・道路縁）を使用しました。",
            "建物の形の一部は、基盤地図情報を基準に独自に測量して作成しました。",
        ])
        XCTAssertFalse(GSIAttribution.aboutParagraphs.joined().contains("承認番号"))
        XCTAssertFalse(GSIAttribution.aboutParagraphs.joined().contains("確認中"))
    }

    func testBlankApprovalNumberFallsBackToPendingNotice() {
        for raw in [nil, "", "   ", "\n\t "] {
            XCTAssertEqual(GSIAttribution.mapShortNotice(approvalNumber: raw), "建物の出典：国土地理院")
            XCTAssertEqual(GSIAttribution.fullNoticeParagraphs(approvalNumber: raw), [
                "この地図の作成に当たっては、国土地理院の基盤地図情報（建築物の外周線・道路縁）を使用しました。",
                "建物の形の一部は、基盤地図情報を基準に独自に測量して作成しました。",
            ])
        }
    }

    func testSettingApprovalNumberSwitchesMapAndAboutNoticesTogether() {
        let shortNotice = GSIAttribution.mapShortNotice(approvalNumber: "  令8情使、第123号  ")
        XCTAssertEqual(shortNotice, "建物：国土地理院 基盤地図情報（承認番号 令8情使、第123号）を使用・加工")

        let paragraphs = GSIAttribution.fullNoticeParagraphs(approvalNumber: "  令8情使、第123号  ")
        XCTAssertEqual(paragraphs, [
            "この地図の作成に当たっては、国土地理院長の承認を得て、同院の基盤地図情報（建築物の外周線・道路縁）を使用した。（承認番号　令8情使、第123号）",
            "建物の形の一部は、基盤地図情報を基準に独自に測量して作成した。",
        ])
    }

    func testAccessibilityLabelMatchesVisibleNotice() {
        XCTAssertEqual(GSIAttribution.accessibilityLabel(), GSIAttribution.mapShortNotice)
        XCTAssertEqual(
            GSIAttribution.accessibilityLabel(for: GSIAttribution.mapShortNotice(approvalNumber: "令8情使、第123号")),
            "建物：国土地理院 基盤地図情報（承認番号 令8情使、第123号）を使用・加工"
        )
    }

    // MARK: - 表示条件（地図表示中のみ常時表示）

    func testMapAttributionShowsOnlyWhenMapContentIsLoaded() {
        let loaded = MapContentState.loaded(CampusMapContent(buildings: [], pins: []))
        let hiddenStates: [MapContentState] = [
            .loading,
            .empty(MapContentStateMessage.notPublished),
            .empty(MapContentStateMessage.noMapInBundle),
            .failed(MapContentStateMessage.loadFailed),
            .failed(MapContentStateMessage.updateRequired),
            .failed(PublishedBundleSourceError.expiredMessage),
        ]

        XCTAssertTrue(GSIAttribution.showsMapAttribution(for: loaded))
        XCTAssertNil(MapSurfaceStateView.Kind(loaded))

        for state in hiddenStates {
            XCTAssertFalse(GSIAttribution.showsMapAttribution(for: state), "\(state)")
            XCTAssertNotNil(MapSurfaceStateView.Kind(state), "\(state)")
        }
    }

    // MARK: - 現在地ボタンとの余白

    func testTrailingPaddingReservesCurrentLocationButtonClearanceAcrossDynamicTypeSizes() {
        XCTAssertEqual(
            MapGSIAttributionView.trailingPadding(
                reservesCurrentLocationButtonSpace: false,
                currentLocationButtonDiameter: CurrentLocationButton.baseDiameter
            ),
            NexusTheme.spacing16
        )

        let regularDiameter = MapGSIAttributionView.currentLocationButtonDiameter(forScaledValue: CurrentLocationButton.baseDiameter)
        XCTAssertEqual(regularDiameter, 56)
        XCTAssertEqual(
            MapGSIAttributionView.trailingPadding(
                reservesCurrentLocationButtonSpace: true,
                currentLocationButtonDiameter: regularDiameter
            ),
            NexusTheme.spacing16 + 56 + NexusTheme.spacing12
        )

        // AX5 でも現在地ボタン上限 68pt と揃えて退避幅を確保する。
        let ax5Diameter = MapGSIAttributionView.currentLocationButtonDiameter(forScaledValue: 96)
        XCTAssertEqual(ax5Diameter, 68)
        XCTAssertEqual(
            MapGSIAttributionView.trailingPadding(
                reservesCurrentLocationButtonSpace: true,
                currentLocationButtonDiameter: ax5Diameter
            ),
            NexusTheme.spacing16 + 68 + NexusTheme.spacing12
        )
    }
}
