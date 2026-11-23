import SwiftUI

struct RouteStepsSectionView: View {
    let steps: [OutdoorRouteStep]
    let routeID: UUID

    // Map の ViewThatFits は同じ要約を通常表示とスクロール表示に持つ。切替時も同じ開閉状態を読む。
    @SceneStorage("route.expandedOutdoorStepsRequestID") private var expandedRouteID: String?
    private var isExpanded: Bool { expandedRouteID == routeID.uuidString }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    expandedRouteID = isExpanded ? nil : routeID.uuidString
                }
            } label: {
                HStack(spacing: NexusTheme.spacing8) {
                    Text("屋外のステップ（\(steps.count)件）")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, NexusTheme.spacing12)
                .nexusTappableRow()
            }
            .buttonStyle(.nexusPressable(cornerRadius: NexusTheme.controlCornerRadius))
            .accessibilityLabel(RouteAccessibilityText.outdoorStepsToggle(count: steps.count))
            .accessibilityValue(isExpanded ? "展開中" : "折りたたみ中")
            .accessibilityHint(isExpanded ? "タップしてステップ一覧を閉じます" : "タップしてステップ一覧を開きます")

            if isExpanded {
                if typeSize.isAccessibilitySize {
                    rows
                } else {
                    ViewThatFits(in: .vertical) {
                        rows.fixedSize(horizontal: false, vertical: true)
                        ScrollView { rows }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .nexusPanel()
        .onChange(of: routeID) { previous, _ in
            if expandedRouteID == previous.uuidString { expandedRouteID = nil }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            ForEach(steps) { step in
                RouteStepRowView(step: step, totalCount: steps.count)
            }
        }
        .padding(.horizontal, NexusTheme.spacing12)
        .padding(.bottom, NexusTheme.spacing12)
    }
}

struct RouteStepRowView: View {
    let step: OutdoorRouteStep
    let totalCount: Int

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                    HStack(spacing: NexusTheme.spacing4) {
                        directionBadge
                        stepNumber
                    }
                    instruction
                    distance
                }
            } else {
                HStack(alignment: .top, spacing: NexusTheme.spacing8) {
                    directionBadge
                    HStack(alignment: .firstTextBaseline, spacing: NexusTheme.spacing8) {
                        stepNumber
                        instruction
                        distance
                    }
                    .frame(minHeight: 28)
                }
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RouteAccessibilityText.outdoorStep(step, totalCount: totalCount))
    }

    private var directionBadge: some View {
        let isDestination = step.kind == .arrive(continuesIndoors: false)
        return Image(systemName: step.systemImageName)
            .foregroundStyle(isDestination ? NexusTheme.onAccent : Color.accentColor)
            .padding(NexusTheme.spacing4)
            .frame(minWidth: 28, minHeight: 28)
            .background(isDestination ? NexusTheme.cautionAccent : NexusTheme.tintSurface, in: Circle())
    }

    private var stepNumber: some View {
        Text("\(step.index).")
            .monospacedDigit()
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
            Text(step.titleText)
                .font(.subheadline.weight(.semibold))
            if let note = step.landmarkNoteText {
                Text(note).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var distance: some View {
        if let distance = step.distanceText {
            Text(distance)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
