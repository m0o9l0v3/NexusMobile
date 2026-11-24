import SwiftUI

struct RouteSummaryCardView: View {
    let route: ResolvedRoute
    let onFitRoute: () -> Void
    let onEndGuidance: () -> Void
    var onChangeOrigin: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    private var row: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing8))
            : AnyLayout(HStackLayout(spacing: NexusTheme.spacing12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            Text("\(route.destination.label)への経路")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let name = route.origin.displayName {
                Text("出発地　\(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            row {
                Label("徒歩 \(RouteSummaryFormatter.formatWalkingDuration(seconds: route.totalEstimatedSeconds))（目安）",
                      systemImage: "figure.walk")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(RouteAccessibilityText.walkingDuration(route))
                Text(RouteSummaryFormatter.formatDistance(meters: route.totalDistanceMeters))
                    .accessibilityLabel(RouteAccessibilityText.distance(route))
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()

            if route.hasIndoorSteps {
                let floors = route.traversedFloorLabels.joined(separator: "、")
                Text(floors.isEmpty ? "屋内区間あり" : "屋内区間あり　\(floors)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !route.outdoorSteps.isEmpty {
                RouteStepsSectionView(steps: route.outdoorSteps, routeID: route.requestID)
            }
            if let onChangeOrigin {
                Button(action: onChangeOrigin) {
                    Text("出発地を変更")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, NexusTheme.spacing12)
                        .padding(.vertical, NexusTheme.spacing8)
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .foregroundStyle(Color.accentColor)
                        .background(NexusTheme.tintSurface, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.nexusPressableCapsule)
            }
            row {
                Button(action: onFitRoute) {
                    Text("全体を表示")
                        .padding(.horizontal, NexusTheme.spacing12)
                        .padding(.vertical, NexusTheme.spacing8)
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .foregroundStyle(Color.accentColor)
                        .background(NexusTheme.tintSurface, in: Capsule())
                        .contentShape(Capsule())
                }
                Button(action: onEndGuidance) {
                    Text("案内を終了")
                        .padding(.horizontal, NexusTheme.spacing12)
                        .padding(.vertical, NexusTheme.spacing8)
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .foregroundStyle(.primary)
                        .background(NexusTheme.surface, in: Capsule())
                        .overlay { Capsule().strokeBorder(NexusTheme.border) }
                        .contentShape(Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.nexusPressableCapsule)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NexusTheme.spacing16)
        .nexusCard(cornerRadius: NexusTheme.primaryCardCornerRadius, elevation: .level3)
    }
}

struct ActiveRouteBannerView: View {
    let route: ResolvedRoute
    let onReturn: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())
        layout {
            Text("案内中　\(route.destination.label)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onReturn) {
                Text("経路へ戻る")
                    .padding(.horizontal, NexusTheme.spacing12)
                    .frame(minHeight: NexusTheme.minimumTapTarget)
                    .foregroundStyle(Color.accentColor)
                    .background(NexusTheme.tintSurface, in: Capsule())
            }
            .buttonStyle(.nexusPressableCapsule)
        }
        .font(.subheadline.weight(.semibold))
        .padding(NexusTheme.spacing12)
        .nexusCard(cornerRadius: NexusTheme.cardCornerRadius, elevation: .level2)
    }
}

#if DEBUG
private struct RouteCardsPreview: View {
    var scenario: RouteCheckFixtures.Scenario = .indoor

    var body: some View {
        if case .accepted(let result) = BundleRouteSolver.resolve(
            in: RouteCheckFixtures.bundle, origin: RouteCheckFixtures.defaultOrigin,
            destinationSpotID: scenario.destination, requestedFrom: .map
        ), let route = result.resolvedRoute {
            ScrollView {
                VStack {
                    ActiveRouteBannerView(route: route, onReturn: {})
                    RouteSummaryCardView(route: route, onFitRoute: {}, onEndGuidance: {})
                }
                .padding()
            }
        }
    }
}

#Preview("ライト") { RouteCardsPreview().preferredColorScheme(.light) }
#Preview("ダーク") { RouteCardsPreview().preferredColorScheme(.dark) }
#Preview("AX3") { RouteCardsPreview().dynamicTypeSize(.accessibility3) }
#Preview("屋外・ライト") { RouteCardsPreview(scenario: .found).preferredColorScheme(.light) }
#Preview("屋外・ダーク") { RouteCardsPreview(scenario: .found).preferredColorScheme(.dark) }
#Preview("屋外・AX3") { RouteCardsPreview(scenario: .found).dynamicTypeSize(.accessibility3) }
#endif
