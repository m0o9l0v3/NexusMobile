import SwiftUI

/// Map の現在地ボタン（#29）。押したときだけ取得と追従を始める（オーナー決定 3-a）。
///
/// MapKit の `MapUserLocationButton` は使わない。あれは MapKit が自分で位置を取りに行き、
/// #25 の権限フロー（アプリの説明・一時的な正確な位置の確認・取得失敗の報告）を通らないため。
struct CurrentLocationButton: View {
    let store: CurrentLocationStore

    @ScaledMetric(relativeTo: .title3) private var scaledDiameter: CGFloat = 48

    /// 大きな文字でも地図を覆いすぎないよう、64pt で止める。タップ領域は 44pt 以上。
    private var diameter: CGFloat {
        min(max(scaledDiameter, NexusTheme.minimumTapTarget), 64)
    }

    var body: some View {
        Button {
            Task { await store.currentLocationButtonTapped() }
        } label: {
            ZStack {
                if store.phase == .locating {
                    ProgressView()
                        .tint(Color.accentColor)
                } else {
                    // 記号は円の大きさに合わせる（AX サイズで円からはみ出さないように）。
                    Image(systemName: store.isFollowing ? "location.fill" : "location")
                        .font(.system(size: diameter * 0.42, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: diameter, height: diameter)
            .background(NexusTheme.cardSurface, in: Circle())
            .overlay { Circle().stroke(NexusTheme.border, lineWidth: 1) }
            .nexusElevation(.level2)
            .contentShape(Circle())
        }
        .buttonStyle(.nexusPressableCircle)
        .accessibilityLabel(CurrentLocationAccessibilityText.buttonLabel)
        .accessibilityValue(CurrentLocationAccessibilityText.buttonValue(phase: store.phase, isFollowing: store.isFollowing))
        .accessibilityHint(CurrentLocationAccessibilityText.buttonHint)
        .accessibilityAddTraits(store.isFollowing ? .isSelected : [])
    }
}

/// 「構内から離れています」（オーナー決定 2-a）。青い点は出したまま、カメラは構内に残す。
struct OffCampusNoticeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NexusTheme.spacing12))

        layout {
            Image(systemName: "location.slash.circle")
                .font(.title3)
                .foregroundStyle(NexusTheme.cautionAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                Text(CurrentLocationAccessibilityText.offCampusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CurrentLocationAccessibilityText.offCampusDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .padding(.vertical, NexusTheme.spacing12)
        .background(NexusTheme.cardSurface, in: RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                .stroke(NexusTheme.border, lineWidth: 1)
        }
        .nexusElevation(.level2)
        .accessibilityElement(children: .combine)
    }
}

/// 地図の上の現在地の点。アクセント色の塗りに OnAccent の縁（主ボタンと同じ組み合わせ）。
struct CurrentLocationDot: View {
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 16, height: 16)
            .overlay { Circle().stroke(NexusTheme.onAccent, lineWidth: 3) }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityElement()
            .accessibilityLabel(CurrentLocationAccessibilityText.dotLabel)
    }
}
