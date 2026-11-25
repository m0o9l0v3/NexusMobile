import SwiftUI

/// メイン地図画面の下部に 1 行で常時表示する国土地理院の出典表示（E1-4 改訂4 K-3 §4.2、M1 v1.0 仕様決定 テーマ2）。
///
/// `MapKitMapSurfaceView` の `.safeAreaInset(edge: .bottom)` として配置することで、
/// MapKit が Apple Maps のロゴと「Legal（法律に基づく情報）」表記を本部品の直上へ自動で退避し、
/// かつ `MapRootView` 側の下部カード（地点詳細・経路要約）の上端にも自動で追従する。
struct MapGSIAttributionView: View {
    let notice: String
    /// 右下に現在地ボタンが表示されるとき、横幅を広げて重ならないよう右側の余白を確保する。
    let reservesCurrentLocationButtonSpace: Bool

    @ScaledMetric(relativeTo: .title3) private var scaledLocationButtonDiameter: CGFloat = CurrentLocationButton.baseDiameter

    init(
        notice: String = GSIAttribution.mapShortNotice,
        reservesCurrentLocationButtonSpace: Bool = false
    ) {
        self.notice = notice
        self.reservesCurrentLocationButtonSpace = reservesCurrentLocationButtonSpace
    }

    private var currentLocationButtonDiameter: CGFloat {
        Self.currentLocationButtonDiameter(forScaledValue: scaledLocationButtonDiameter)
    }

    private var trailingPadding: CGFloat {
        Self.trailingPadding(
            reservesCurrentLocationButtonSpace: reservesCurrentLocationButtonSpace,
            currentLocationButtonDiameter: currentLocationButtonDiameter
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(notice)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .padding(.horizontal, NexusTheme.spacing8)
                .padding(.vertical, NexusTheme.spacing4)
                .background(NexusTheme.cardSurface, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(NexusTheme.border, lineWidth: 1)
                }
                .nexusElevation(.level1)
            Spacer(minLength: 0)
        }
        .padding(.leading, NexusTheme.spacing16)
        .padding(.trailing, trailingPadding)
        .padding(.top, NexusTheme.spacing4)
        .padding(.bottom, NexusTheme.spacing12)
        // 地図のドラッグ・ピン選択や Apple Maps の Legal タップを妨げない。VoiceOver にはそのまま読み上げる。
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GSIAttribution.accessibilityLabel(for: notice))
        .accessibilityAddTraits(.isStaticText)
        .accessibilitySortPriority(-10)
        .accessibilityIdentifier("map.gsiAttribution")
    }

    /// `CurrentLocationButton` と同じ直径上限（44〜68pt）で右側の退避幅を揃える。
    static func currentLocationButtonDiameter(forScaledValue scaled: CGFloat) -> CGFloat {
        CurrentLocationButton.diameter(forScaledValue: scaled)
    }

    /// 右下の現在地ボタンと重ならないための右側余白。
    static func trailingPadding(
        reservesCurrentLocationButtonSpace: Bool,
        currentLocationButtonDiameter: CGFloat
    ) -> CGFloat {
        guard reservesCurrentLocationButtonSpace else {
            return NexusTheme.spacing16
        }
        return NexusTheme.spacing16 + currentLocationButtonDiameter + NexusTheme.spacing12
    }
}

#if DEBUG
#Preview("ライト") {
    MapGSIAttributionView(reservesCurrentLocationButtonSpace: true)
        .preferredColorScheme(.light)
}

#Preview("ダーク") {
    MapGSIAttributionView(reservesCurrentLocationButtonSpace: true)
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    MapGSIAttributionView(reservesCurrentLocationButtonSpace: true)
        .dynamicTypeSize(.accessibility5)
}
#endif
