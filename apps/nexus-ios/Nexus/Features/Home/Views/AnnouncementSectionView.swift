import SwiftUI

struct AnnouncementSectionView: View {
    let announcements: [HomeAnnouncement]
    let badgeCount: Int?
    let onShowAll: () -> Void
    let onSelect: (HomeAnnouncement) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ForEach(announcements) { announcement in
                Divider()

                Button {
                    onSelect(announcement)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Text(announcement.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let elapsedText = announcement.elapsedText {
                                    Text(elapsedText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(announcement.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)

                                if let elapsedText = announcement.elapsedText {
                                    Text(elapsedText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 15)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: announcement))
                .accessibilityHint("お知らせ詳細への遷移要求を送ります")
            }
        }
        .background(NexusTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                .stroke(NexusTheme.border, lineWidth: 1)
        }
        .accessibilitySortPriority(70)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("お知らせ")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            if let badgeCount, badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Color.red, in: Capsule())
                    .accessibilityLabel("\(announcements.count)件")
            }

            Spacer(minLength: 8)

            Button(action: onShowAll) {
                HStack(spacing: 2) {
                    Text("すべて見る")
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.caption)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityHint("お知らせ一覧への遷移要求を送ります")
        }
        .padding(.leading, 15)
        .padding(.trailing, 16)
        .frame(minHeight: 44)
        .background(Color(.systemBackground))
    }

    private func accessibilityLabel(for announcement: HomeAnnouncement) -> String {
        if let elapsedText = announcement.elapsedText {
            return "\(announcement.title)、\(elapsedText)"
        }
        return announcement.title
    }
}
