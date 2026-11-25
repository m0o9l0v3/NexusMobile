import SwiftUI

/// Map の現在地ボタン（#29）。押したときだけ取得と追従を始める（オーナー決定 3-a）。
///
/// MapKit の `MapUserLocationButton` は使わない。あれは MapKit が自分で位置を取りに行き、
/// #25 の権限フロー（アプリの説明・一時的な正確な位置の確認・取得失敗の報告）を通らないため。
struct CurrentLocationButton: View {
    static let baseDiameter: CGFloat = 56
    static let maxDiameter: CGFloat = 68

    static func diameter(forScaledValue scaled: CGFloat) -> CGFloat {
        min(max(scaled, NexusTheme.minimumTapTarget), maxDiameter)
    }

    let store: CurrentLocationStore

    @ScaledMetric(relativeTo: .title3) private var scaledDiameter: CGFloat = CurrentLocationButton.baseDiameter
    @State private var tapFeedbackCount = 0

    /// 大きな文字でも地図を覆いすぎないよう、68pt で止める。タップ領域は 44pt 以上。
    private var diameter: CGFloat {
        Self.diameter(forScaledValue: scaledDiameter)
    }

    var body: some View {
        Button {
            tapFeedbackCount += 1
            Task { await store.currentLocationButtonTapped() }
        } label: {
            ZStack {
                if store.phase == .locating {
                    ProgressView()
                        .tint(Color.accentColor)
                } else if store.isLocationOff {
                    // 位置情報オフ（#31）。理由の表示と同じ記号・色（CautionAccent）。
                    Image(systemName: "location.slash")
                        .font(.system(size: diameter * 0.42, weight: .semibold))
                        .foregroundStyle(NexusTheme.cautionAccent)
                } else {
                    // 記号は円の大きさに合わせる（AX サイズで円からはみ出さないように）。
                    Image(systemName: store.isFollowing ? "location.fill" : "location")
                        .font(.system(size: diameter * 0.42, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.nexusFloatingCircle)
        .sensoryFeedback(.impact(weight: .light), trigger: tapFeedbackCount)
        .accessibilityLabel(CurrentLocationAccessibilityText.buttonLabel)
        .accessibilityValue(CurrentLocationAccessibilityText.buttonValue(
            phase: store.phase,
            isFollowing: store.isFollowing,
            isLocationOff: store.isLocationOff
        ))
        .accessibilityHint(store.isLocationOff ? CurrentLocationAccessibilityText.locationOffHint : CurrentLocationAccessibilityText.buttonHint)
        .accessibilityAddTraits(store.isFollowing ? .isSelected : [])
    }
}

/// 「構内から離れています」。構外でも現在地へ追従し、「構内に戻る」で構内全体へ戻せる。
struct OffCampusNoticeView: View {
    let onReturnToCampus: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var returnFeedbackCount = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            compactBar
            stackedCard
        }
        .sensoryFeedback(.impact(weight: .light), trigger: returnFeedbackCount)
        .accessibilityElement(children: .contain)
    }

    private var compactBar: some View {
        HStack(alignment: .center, spacing: 10) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrentLocationAccessibilityText.offCampusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                Text(CurrentLocationAccessibilityText.offCampusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: NexusTheme.spacing4)

            returnButton(fullWidth: false)
        }
        .padding(.leading, NexusTheme.spacing12)
        .padding(.trailing, NexusTheme.spacing8)
        .padding(.vertical, NexusTheme.spacing8)
        .frame(maxWidth: .infinity)
        .nexusFloatingGlass(in: Capsule(), interactive: false)
    }

    private var stackedCard: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 10) {
                iconBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(CurrentLocationAccessibilityText.offCampusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CurrentLocationAccessibilityText.offCampusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            returnButton(fullWidth: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, NexusTheme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nexusFloatingGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: false)
    }

    private var iconBadge: some View {
        Circle()
            .fill(NexusTheme.cautionSurface)
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: "map")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NexusTheme.cautionAccent)
            }
            .accessibilityHidden(true)
    }

    private func returnButton(fullWidth: Bool) -> some View {
        Button {
            returnFeedbackCount += 1
            onReturnToCampus()
        } label: {
            Text(CurrentLocationAccessibilityText.returnToCampusButtonTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NexusTheme.onAccent)
                .lineLimit(fullWidth ? nil : 1)
                .fixedSize(horizontal: !fullWidth, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, NexusTheme.spacing8)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: NexusTheme.minimumTapTarget)
                .background(Color.accentColor, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(ProminentCapsuleButtonStyle())
    }
}

private struct ProminentCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.75),
                value: configuration.isPressed
            )
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
