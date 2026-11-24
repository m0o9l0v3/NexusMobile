import SwiftUI

extension View {
    func routePreviewSheet(model: AppShellModel) -> some View {
        let store = model.routeStore
        return sheet(item: Binding(get: { store.previewSession }, set: { session in
            if session == nil { store.dismissPreview() }
        })) { session in
            RoutePreviewSheet(session: session, store: store, currentLocation: model.currentLocation,
                              originStore: model.routeOriginStore, coordinator: model.coordinator())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(NexusTheme.cardSurface)
                .presentationBackgroundInteraction(.disabled)
                .presentationContentInteraction(.scrolls)
        }
    }
}

private struct RoutePreviewSheet: View {
    let session: RouteRequestStore.PreviewSession
    let store: RouteRequestStore
    let currentLocation: CurrentLocationStore
    let originStore: ManualRouteOriginStore
    let coordinator: AppRouteCoordinator

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState(for: .voiceOver) private var isTitleFocused: Bool

    private var result: RoutePreview? { store.previewResult }
    private var target: RoutePreviewTarget { result?.target ?? session.target }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                    Text(target.displayName)
                        .font(.title3.bold())
                        .accessibilityLabel("経路プレビュー、目的地、\(target.displayName)")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    if !target.locationText.isEmpty {
                        Text(target.locationText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let result {
                    if let saved = result.savedMetadata {
                        SavedContentBannerView(metadata: saved)
                    }
                    if let route = result.destination?.resolvedRoute {
                        routeContent(route, buildings: result.buildings)
                    } else {
                        NexusStatusView(message: result.statusMessage)
                    }
                } else {
                    ProgressView("経路を確認中")
                        .frame(maxWidth: .infinity, minHeight: 154)
                }

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.top, NexusTheme.spacing20)
            .padding(.bottom, NexusTheme.spacing8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task {
            isTitleFocused = true
            let fix = await currentLocation.routePreviewFix()
            await store.loadPreview(id: session.id, currentFix: fix, manualOrigin: originStore.selectedOrigin)
        }
    }

    private func routeContent(_ route: ResolvedRoute, buildings: [CampusMapContent.Building]) -> some View {
        let duration = RouteSummaryFormatter.formatWalkingDuration(seconds: route.totalEstimatedSeconds)
        let distance = RouteSummaryFormatter.formatDistance(meters: route.totalDistanceMeters)

        return VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            RoutePreviewMap(route: route, buildings: buildings)
                .frame(height: 154)
                .clipShape(RoundedRectangle(cornerRadius: NexusTheme.controlCornerRadius))
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Text("建物の出典：国土地理院")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("出発地：\(route.origin.label)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Label("徒歩 \(duration) (\(distance))", systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel("\(RouteAccessibilityText.walkingDuration(route))、\(RouteAccessibilityText.distance(route))")

            Button {
                coordinator.startPreviewedRoute(id: session.id)
            } label: {
                Label("案内を開始する", systemImage: "location.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NexusTheme.onAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.accentColor, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.nexusPressableCapsule)
            .nexusElevation(.level2)
        }
    }
}
