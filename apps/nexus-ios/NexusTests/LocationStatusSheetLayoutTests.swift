import SwiftUI
import UIKit
import XCTest
@testable import Nexus

/// タブバーから伸びる下のシート（`.locationPermissionFlow` の理由の表示）の寸法。
///
/// 以前は高さの上限を「シートを差し引いた後の高さ」の 6 割にしていたため、上限が約 0.375 倍まで縮み、
/// 標準の文字サイズでも ScrollView に切り替わってシートの下が四角く切れていた。
@MainActor
final class LocationStatusSheetLayoutTests: XCTestCase {
    /// iPhone SE（第3世代）の縦 667pt から、ステータスバー 20pt とタブバー 49pt を除いた、タブの中身の高さ。
    /// 対応する端末でいちばん低い。
    private static let smallestContainerHeight: CGFloat = 667 - 20 - 49
    /// iPhone SE の幅 375pt から、シートの左右の余白（8）と中身の左右の余白（20）を除いた幅。
    private static let smallestContentWidth: CGFloat =
        375 - NexusTheme.attachedSheetMargin * 2 - LocationStatusSheetLayout.horizontalPadding * 2

    private static let nonAllowedStates: [LocationPermissionState] = [
        .deferred,
        .denied(.userDenied),
        .denied(.servicesOff),
        .denied(.restricted),
        .unavailable,
        .reducedAccuracy,
    ]

    func testMaxContentHeightIsFractionOfFullContainer() throws {
        let height = try XCTUnwrap(LocationStatusSheetLayout.maxContentHeight(containerHeight: 720))
        XCTAssertEqual(height, 432, accuracy: 0.001)
    }

    func testMaxContentHeightIsUnsetBeforeMeasuring() {
        XCTAssertNil(LocationStatusSheetLayout.maxContentHeight(containerHeight: 0))
    }

    /// 標準の文字サイズでは、どの状態の理由の表示も上限に収まる（スクロールにならず、シートが切れない）。
    func testEveryStatusFitsWithoutScrollingAtDefaultTextSize() throws {
        let cap = try XCTUnwrap(LocationStatusSheetLayout.maxContentHeight(containerHeight: Self.smallestContainerHeight))
        for state in Self.nonAllowedStates {
            let guidance = try XCTUnwrap(LocationPermissionGuidance(state: state))
            let height = Self.idealHeight(
                of: LocationPermissionStatusView(guidance: guidance, onAction: { _ in }, onDismiss: {}, chrome: .plain)
                    .environment(\.dynamicTypeSize, .large),
                width: Self.smallestContentWidth
            )
            XCTAssertLessThanOrEqual(height, cap, "\(state): \(height)pt > \(cap)pt")
        }
    }

    /// 上限より低い中身では、上限まで広がらず中身の高さのままにする（`.frame(maxHeight:)` は広がってしまう）。
    func testCappedLayoutKeepsShorterContentHeight() {
        let height = Self.idealHeight(
            of: CappedHeightLayout(maxHeight: 300) {
                ViewThatFits(in: .vertical) {
                    Color.clear.frame(height: 120)
                    ScrollView { Color.clear.frame(height: 120) }
                }
            },
            width: 300,
            proposedHeight: 800
        )
        XCTAssertEqual(height, 120, accuracy: 0.5)
    }

    /// 上限を超える中身（AX サイズ）では、ScrollView を選んで上限の高さにする。
    func testCappedLayoutScrollsTallerContentAtCap() {
        let height = Self.idealHeight(
            of: CappedHeightLayout(maxHeight: 300) {
                ViewThatFits(in: .vertical) {
                    Color.clear.frame(height: 500)
                    ScrollView { Color.clear.frame(height: 500) }
                }
            },
            width: 300,
            proposedHeight: 800
        )
        XCTAssertEqual(height, 300, accuracy: 0.5)
    }

    func testCappedLayoutWithoutCapPassesProposalThrough() {
        let height = Self.idealHeight(
            of: CappedHeightLayout(maxHeight: nil) { Color.clear.frame(height: 120) },
            width: 300,
            proposedHeight: 800
        )
        XCTAssertEqual(height, 120, accuracy: 0.5)
    }

    func testSheetGeometryFollowsDesignRules() {
        // デザインルール：ボトムナビ外枠 22-28px、余白 16 / 20。
        XCTAssertEqual(NexusTheme.attachedSheetTopCornerRadius, 28)
        XCTAssertEqual(NexusTheme.attachedSheetMargin, 8)
        XCTAssertEqual(LocationStatusSheetLayout.topPadding, 20)
        XCTAssertEqual(LocationStatusSheetLayout.horizontalPadding, 20)
        XCTAssertEqual(LocationStatusSheetLayout.bottomPadding, 16)
    }

    // MARK: - Helpers

    private static func idealHeight<V: View>(of view: V, width: CGFloat, proposedHeight: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: width, height: proposedHeight)).height
    }
}
