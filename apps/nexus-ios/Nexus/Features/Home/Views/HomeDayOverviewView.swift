import SwiftUI

/// A. 開催日カード（Home v1.0 下書き、Figma `2798:1513` の `HomeDraft/DayOverview`、状態一覧 `2790:1744`）。
/// 中止は色だけに頼らず、文言・アイコン・枠で示す。
struct HomeDayOverviewView: View {
    let overview: HomeDayOverview

    private var isCancelled: Bool { overview.status == .cancelled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .accessibilityHidden(true)

                Text("オープンキャンパス開催日")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HomeDayStatusBadge(status: overview.status)
            }
            .foregroundStyle(isCancelled ? Color.red : Color.secondary)

            Text(overview.dateText)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let detailText = overview.detailText {
                Text(detailText)
                    .font(isCancelled ? .headline : .footnote)
                    .foregroundStyle(isCancelled ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cancelNote = overview.cancelNote {
                Text("理由：\(cancelNote)")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !overview.otherDays.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("ほかの開催日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(overview.otherDays) { day in
                        Text(day.isCancelled ? "\(day.dateText)（中止）" : day.dateText)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 中止は色だけに頼らず、バッジの文字・アイコン・文言に加えて下地と枠でも示す。
        .background(isCancelled ? Color.red.opacity(0.08) : Color.clear)
        .nexusCard(cornerRadius: NexusTheme.primaryCardCornerRadius)
        .overlay {
            if isCancelled {
                RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous)
                    .stroke(Color.red, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(90)
    }
}

private struct HomeDayStatusBadge: View {
    let status: HomeDayStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .cancelled {
                Image(systemName: "xmark.circle")
                    .accessibilityHidden(true)
            }
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(background, in: Capsule())
    }

    private var title: String {
        switch status {
        case .upcoming: return "開催前"
        case .open: return "開催中"
        case .ended: return "終了"
        case .today: return "本日"
        case .cancelled: return "中止"
        }
    }

    private var foreground: Color {
        switch status {
        case .open, .cancelled: return .white
        case .upcoming, .today: return .accentColor
        case .ended: return .secondary
        }
    }

    private var background: Color {
        switch status {
        case .open: return .accentColor
        case .cancelled: return .red
        case .upcoming, .today: return NexusTheme.tintSurface
        case .ended: return NexusTheme.surface
        }
    }
}

#if DEBUG
#Preview("開催日カード") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(HomePreviewFixtures.dayOverviews, id: \.dayID) { overview in
                HomeDayOverviewView(overview: overview)
            }
        }
        .padding(20)
    }
}
#endif
